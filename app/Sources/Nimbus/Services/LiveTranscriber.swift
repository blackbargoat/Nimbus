import AVFoundation
import Foundation
import os
import Speech

let sttLog = Logger(subsystem: "app.nimbus.classnotes", category: "speech")

/// Listens to the microphone and turns speech into text on the Mac itself,
/// using Apple's built-in speech model (no audio leaves the computer).
@MainActor
final class LiveTranscriber {
    enum Failure: LocalizedError {
        case micDenied, speechDenied, noLocale, noFormat

        var errorDescription: String? {
            switch self {
            case .micDenied: "Nimbus needs microphone access. Turn it on in System Settings > Privacy & Security > Microphone."
            case .speechDenied: "Nimbus needs speech recognition. Turn it on in System Settings > Privacy & Security > Speech Recognition."
            case .noLocale: "Your Mac's language isn't supported for live transcription yet."
            case .noFormat: "Couldn't set up the microphone audio format."
            }
        }
    }

    /// Text that is still being heard and may change.
    var onPartial: (String) -> Void = { _ in }
    /// A finished line and the seconds into the recording it started.
    var onLine: (String, TimeInterval) -> Void = { _, _ in }
    /// The speech engine stopped with an error.
    var onError: (String) -> Void = { _ in }
    /// Mic loudness from 0 to 1, for the cloud's animation. Called on the audio thread.
    var onLevel: @Sendable (Float) -> Void = { _ in }

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var offset: TimeInterval = 0
    private var testTask: Task<Void, Never>?

    /// - Parameter offset: seconds already recorded in this class, so resumed
    ///   recordings keep counting from where they left off.
    func start(locale preferred: Locale, offset: TimeInterval) async throws {
        self.offset = offset
        try await Self.requestPermissions()

        var match = await SpeechTranscriber.supportedLocale(equivalentTo: preferred)
        if match == nil {
            match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        }
        guard let locale = match else { throw Failure.noLocale }
        _ = try? await AssetInventory.reserve(locale: locale)

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        // First run downloads Apple's speech model for this language (once).
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let targetFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        else { throw Failure.noFormat }
        self.analyzer = analyzer
        sttLog.info("speech ready: locale \(locale.identifier, privacy: .public), format \(targetFormat, privacy: .public)")

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let self else { return }
                    if result.isFinal {
                        sttLog.debug("final line, \(text.count) chars")
                        if !text.isEmpty { self.onLine(text, self.offset + result.range.start.seconds) }
                        self.onPartial("")
                    } else {
                        self.onPartial(text)
                    }
                }
            } catch {
                sttLog.error("speech results ended: \(String(describing: error), privacy: .public)")
                if !Task.isCancelled { self?.onError("Speech recognition stopped: \(error.localizedDescription)") }
            }
        }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        input = continuation
        try await analyzer.start(inputSequence: stream)
        if let path = ProcessInfo.processInfo.environment["NIMBUS_TEST_AUDIO"] {
            try playTestFile(path, feeding: continuation, as: targetFormat)
        } else {
            try startEngine(feeding: continuation, as: targetFormat)
        }
    }

    func stop() async {
        testTask?.cancel()
        testTask = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        input?.finish()
        input = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        await resultsTask?.value
        resultsTask = nil
        onLevel(0)
        onPartial("")
    }

    private func startEngine(feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
                             as targetFormat: AVAudioFormat) throws {
        let node = engine.inputNode
        let micFormat = node.outputFormat(forBus: 0)
        sttLog.info("mic format \(micFormat, privacy: .public)")
        guard micFormat.sampleRate > 0, micFormat.channelCount > 0 else {
            throw NSError(domain: "Nimbus", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "No microphone found. Pick one in System Settings > Sound > Input."])
        }
        guard let converter = AVAudioConverter(from: micFormat, to: targetFormat) else { throw Failure.noFormat }
        node.installTap(onBus: 0, bufferSize: 4096, format: micFormat,
                        block: Self.tap(converter: converter, from: micFormat, to: targetFormat,
                                        feeding: continuation, onLevel: onLevel))
        engine.prepare()
        try engine.start()
    }

    /// Test mode: plays an audio file through the same path as the mic, in real time.
    private func playTestFile(_ path: String, feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
                              as targetFormat: AVAudioFormat) throws {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let format = file.processingFormat
        guard let converter = AVAudioConverter(from: format, to: targetFormat) else { throw Failure.noFormat }
        let tap = Self.tap(converter: converter, from: format, to: targetFormat, feeding: continuation, onLevel: onLevel)
        sttLog.info("test audio \(path, privacy: .public)")
        testTask = Task.detached {
            while !Task.isCancelled, file.framePosition < file.length {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800),
                      (try? file.read(into: buffer)) != nil, buffer.frameLength > 0 else { break }
                tap(buffer, AVAudioTime(sampleTime: file.framePosition, atRate: format.sampleRate))
                try? await Task.sleep(for: .seconds(Double(buffer.frameLength) / format.sampleRate))
            }
        }
    }

    /// Built outside the main actor because Core Audio calls it on its own thread.
    private nonisolated static func tap(converter: AVAudioConverter,
                                        from micFormat: AVAudioFormat,
                                        to targetFormat: AVAudioFormat,
                                        feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
                                        onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            onLevel(level(of: buffer))
            let ratio = targetFormat.sampleRate / micFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
            var fed = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if fed {
                    status.pointee = .noDataNow
                    return nil
                }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, out.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: out))
            }
        }
    }

    private nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        return min(1, rms * 12)
    }

    private static func requestPermissions() async throws {
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard mic else { throw Failure.micDenied }
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { throw Failure.speechDenied }
    }
}
