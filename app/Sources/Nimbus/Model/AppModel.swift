import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum CloudMood { case idle, listening, thinking, done }

    var sessions: [ClassSession] = SessionStore.loadAll()
    var selectedID: UUID?
    var isRecording = false
    var isStarting = false
    var partial = ""
    var level: Float = 0
    var isUpdatingNotes = false
    var isAsking = false
    var message: String?
    var recordingStartedAt: Date?
    /// Briefly true after fresh notes land, so the cloud can celebrate.
    var justFinishedNotes = false
    /// The answer showing in the bubble next to the cloud.
    var liveAnswer: LiveAnswer?
    var isAnswering = false

    @ObservationIgnored let defaults = UserDefaults.standard
    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: "serverURL") }
    }
    /// Minutes between automatic note updates while recording.
    var autoNotesMinutes: Double {
        didSet { defaults.set(autoNotesMinutes, forKey: "autoNotesMinutes") }
    }

    /// Answer the teacher's questions automatically while listening.
    var liveAnswersOn: Bool {
        didSet { defaults.set(liveAnswersOn, forKey: "liveAnswersOn") }
    }

    @ObservationIgnored private var lastAutoAnswer = Date.distantPast
    /// Loudest mic level since recording started, to catch a silent or wrong mic.
    @ObservationIgnored private var loudest: Float = 0
    @ObservationIgnored private var silenceCheck: Task<Void, Never>?
    @ObservationIgnored private var answerTask: Task<Void, Never>?
    @ObservationIgnored private var hideBubbleTask: Task<Void, Never>?
    @ObservationIgnored private let transcriber = LiveTranscriber()
    @ObservationIgnored private var autoNotesTask: Task<Void, Never>?
    @ObservationIgnored private var baseDuration: TimeInterval = 0

    /// Optional shared notes server. Empty means Nimbus calls Claude with your own key.
    static let defaultServer = ""

    enum Provider: String, CaseIterable, Identifiable {
        case gemini = "Google Gemini", claude = "Claude"
        var id: String { rawValue }
    }

    var provider: Provider = Provider(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .gemini {
        didSet { defaults.set(provider.rawValue, forKey: "provider") }
    }
    var apiKey: String = KeyStore.load(.claude) {
        didSet { KeyStore.save(apiKey, as: .claude) }
    }
    var googleKey: String = KeyStore.load(.google) {
        didSet { KeyStore.save(googleKey, as: .google) }
    }
    /// brain.md, kept in memory and saved as it changes.
    var brain: String = Brain.load() {
        didSet { Brain.save(brain) }
    }

    private var activeKey: String { provider == .gemini ? googleKey : apiKey }
    var hasAI: Bool { !activeKey.isEmpty || !serverURL.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        serverURL = defaults.string(forKey: "serverURL") ?? Self.defaultServer
        let minutes = defaults.double(forKey: "autoNotesMinutes")
        autoNotesMinutes = minutes > 0 ? minutes : 4
        liveAnswersOn = defaults.object(forKey: "liveAnswersOn") as? Bool ?? true
        selectedID = sessions.first?.id

        transcriber.onPartial = { [weak self] in self?.partial = $0 }
        transcriber.onLevel = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.level = value
                self.loudest = max(self.loudest, value)
            }
        }
        transcriber.onLine = { [weak self] text, at in self?.appendLine(text, at: at) }
        transcriber.onError = { [weak self] in self?.message = $0 }
    }

    var mood: CloudMood {
        if isUpdatingNotes || isAsking || isStarting || isAnswering { return .thinking }
        if justFinishedNotes { return .done }
        return isRecording ? .listening : .idle
    }

    var selected: ClassSession? {
        get { sessions.first { $0.id == selectedID } }
        set {
            guard let newValue, let i = sessions.firstIndex(where: { $0.id == newValue.id }) else { return }
            sessions[i] = newValue
            SessionStore.save(newValue)
        }
    }

    var recordingSessionID: UUID?

    // MARK: Sessions

    @discardableResult
    func newSession() -> ClassSession {
        let title = "Class, " + Date().formatted(.dateTime.weekday(.wide).month().day().hour().minute())
        let session = ClassSession(title: title)
        sessions.insert(session, at: 0)
        selectedID = session.id
        SessionStore.save(session)
        return session
    }

    func rename(_ id: UUID, to title: String) {
        update(id) { $0.title = title }
    }

    func delete(_ id: UUID) {
        if recordingSessionID == id { Task { await stopRecording() } }
        sessions.removeAll { $0.id == id }
        SessionStore.delete(id)
        if selectedID == id { selectedID = sessions.first?.id }
    }

    private func update(_ id: UUID, _ change: (inout ClassSession) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[i])
        SessionStore.save(sessions[i])
    }

    // MARK: Recording

    func toggleRecording() {
        Task { isRecording ? await stopRecording() : await startRecording() }
    }

    func startRecording() async {
        guard !isRecording, !isStarting else { return }
        let session = selected ?? newSession()
        recordingSessionID = session.id
        baseDuration = session.duration
        isStarting = true
        message = nil
        do {
            try await transcriber.start(locale: Locale.current, offset: session.duration)
            isRecording = true
            recordingStartedAt = Date()
            scheduleAutoNotes()
            loudest = 0
            silenceCheck?.cancel()
            silenceCheck = Task { [weak self] in
                try? await Task.sleep(for: .seconds(12))
                guard let self, !Task.isCancelled, self.isRecording, self.loudest < 0.02 else { return }
                self.message = "I can't hear anything. Check that the right microphone is picked in System Settings > Sound > Input, and that Nimbus is allowed in Privacy & Security > Microphone."
            }
        } catch {
            message = error.localizedDescription
            recordingSessionID = nil
        }
        isStarting = false
    }

    func stopRecording() async {
        guard isRecording, let id = recordingSessionID else { return }
        autoNotesTask?.cancel()
        silenceCheck?.cancel()
        sttLog.info("stopping, loudest mic level \(self.loudest, privacy: .public)")
        await transcriber.stop()
        isRecording = false
        partial = ""
        if let start = recordingStartedAt {
            update(id) { $0.duration = baseDuration + Date().timeIntervalSince(start) }
        }
        recordingStartedAt = nil
        recordingSessionID = nil
        // One last pass so the notes cover the whole class.
        if let session = sessions.first(where: { $0.id == id }), session.lines.count > session.notesLineCount {
            await updateNotes(id)
        }
        // Teach the brain what this class covered.
        if let session = sessions.first(where: { $0.id == id }), session.notes != nil {
            Brain.learn(from: session)
            brain = Brain.load()
        }
    }

    /// Seconds recorded so far in the current or selected class.
    func elapsed(at now: Date = .now) -> TimeInterval {
        if isRecording, let start = recordingStartedAt { return baseDuration + now.timeIntervalSince(start) }
        return selected?.duration ?? 0
    }

    private func appendLine(_ text: String, at: TimeInterval) {
        guard let id = recordingSessionID else { return }
        update(id) { $0.lines.append(TranscriptLine(text: text, at: at)) }
        if liveAnswersOn, !isAnswering, Date().timeIntervalSince(lastAutoAnswer) > 20,
           QuestionDetector.isQuestion(text) {
            lastAutoAnswer = Date()
            answerLive(text, at: at, auto: true)
        }
    }

    // MARK: Live answers

    /// "Help me answer": treat the last thing the teacher said as the question.
    func helpMeAnswer() {
        guard let session = sessions.first(where: { $0.id == (recordingSessionID ?? selectedID) }) else { return }
        let recent = session.lines.suffix(2).map(\.text).joined(separator: " ")
        let question = [recent, partial].filter { !$0.isEmpty }.joined(separator: " ")
        guard !question.isEmpty else {
            message = "I haven't heard anything yet. Start listening first."
            return
        }
        answerLive(question, at: session.lines.last?.at ?? 0, auto: false)
    }

    private func answerLive(_ question: String, at: TimeInterval, auto: Bool) {
        guard let id = recordingSessionID ?? selectedID,
              let session = sessions.first(where: { $0.id == id }) else { return }
        answerTask?.cancel()
        hideBubbleTask?.cancel()
        var answer = LiveAnswer(question: question, at: at)
        liveAnswer = answer
        isAnswering = true
        answerTask = Task {
            do {
                for try await chunk in try streamLiveAnswer(question, session) {
                    answer.answer += chunk
                    if liveAnswer?.id == answer.id { liveAnswer = answer }
                }
                answer.isDone = true
                let text = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.hasPrefix("SKIP") {
                    if liveAnswer?.id == answer.id { liveAnswer = nil }
                    if !auto { message = "That didn't sound like a question to the class." }
                } else {
                    answer.answer = text
                    if liveAnswer?.id == answer.id { liveAnswer = answer }
                    update(id) { $0.answers.append(answer) }
                    scheduleBubbleHide(answer.id)
                }
            } catch is CancellationError {
            } catch {
                answer.answer = "I couldn't answer that: \(error.localizedDescription)"
                answer.isDone = true
                if liveAnswer?.id == answer.id { liveAnswer = answer }
                scheduleBubbleHide(answer.id)
            }
            isAnswering = false
        }
    }

    /// Bubble hangs around long enough to read, then floats away.
    func scheduleBubbleHide(_ id: UUID, after seconds: Double = 45) {
        hideBubbleTask?.cancel()
        hideBubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, liveAnswer?.id == id else { return }
            liveAnswer = nil
        }
    }

    func keepBubble() { hideBubbleTask?.cancel() }

    /// Demo for screenshots: streams a canned answer into the bubble.
    func demoBubble() {
        var a = LiveAnswer(question: "Why do you think a country would give up some of its sovereignty?", at: 0)
        liveAnswer = a
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            let text = "**Say:** Because teaming up gets them stuff they can't get alone, like trade deals and safety.\n- EU members get the single market, so it's cheaper to trade\n- Together they have more say than one small country\n**Key idea:** pooled sovereignty"
            for word in text.split(separator: " ", omittingEmptySubsequences: false) {
                a.answer += (a.answer.isEmpty ? "" : " ") + word
                liveAnswer = a
                try? await Task.sleep(for: .milliseconds(45))
            }
            a.isDone = true
            liveAnswer = a
        }
    }

    func dismissBubble() {
        hideBubbleTask?.cancel()
        liveAnswer = nil
    }

    private func scheduleAutoNotes() {
        autoNotesTask?.cancel()
        autoNotesTask = Task { [weak self] in
            while !Task.isCancelled {
                let minutes = self?.autoNotesMinutes ?? 4
                try? await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled, let self, let id = self.recordingSessionID,
                      let s = self.sessions.first(where: { $0.id == id }),
                      s.lines.count - s.notesLineCount >= 4
                else { continue }
                await self.updateNotes(id)
            }
        }
    }

    // MARK: Claude

    private var server: NotesClient { NotesClient(baseURL: serverURL) }
    private var gemini: GeminiDirect? {
        provider == .gemini && !googleKey.isEmpty ? GeminiDirect(apiKey: googleKey, brain: brain) : nil
    }
    private var claude: ClaudeDirect? {
        provider == .claude && !apiKey.isEmpty ? ClaudeDirect(apiKey: apiKey, brain: brain) : nil
    }

    private func requireAI() throws {
        guard hasAI else {
            throw NotesClient.Failure.server("Add your \(provider == .gemini ? "Google" : "Claude") API key in Settings so I can write notes.")
        }
    }

    private func fetchNotes(_ s: ClassSession) async throws -> ClassNotes {
        try requireAI()
        if let gemini { return try await gemini.notes(for: s) }
        if let claude { return try await claude.notes(for: s) }
        return try await server.notes(for: s)
    }

    private func fetchAnswer(_ q: String, _ s: ClassSession) async throws -> String {
        try requireAI()
        if let gemini { return try await gemini.ask(q, in: s) }
        if let claude { return try await claude.ask(q, in: s) }
        return try await server.ask(q, in: s)
    }

    private func streamLiveAnswer(_ q: String, _ s: ClassSession) throws -> AsyncThrowingStream<String, Error> {
        try requireAI()
        if let gemini { return gemini.answer(q, in: s) }
        if let claude { return claude.answer(q, in: s) }
        return server.answer(q, in: s)
    }

    func updateNotes(_ id: UUID? = nil) async {
        guard let id = id ?? selectedID,
              let session = sessions.first(where: { $0.id == id }),
              !session.lines.isEmpty, !isUpdatingNotes
        else { return }
        isUpdatingNotes = true
        defer { isUpdatingNotes = false }
        do {
            let notes = try await fetchNotes(session)
            update(id) {
                $0.notes = notes
                $0.notesUpdatedAt = Date()
                $0.notesLineCount = session.lines.count
            }
            celebrate()
        } catch {
            message = error.localizedDescription
        }
    }

    func ask(_ question: String) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let id = selectedID, let session = selected else { return }
        update(id) { $0.chat.append(ChatMessage(role: .user, text: q)) }
        isAsking = true
        defer { isAsking = false }
        do {
            let answer = try await fetchAnswer(q, session)
            update(id) { $0.chat.append(ChatMessage(role: .assistant, text: answer)) }
        } catch {
            update(id) { $0.chat.append(ChatMessage(role: .assistant, text: "I couldn't answer that: \(error.localizedDescription)")) }
        }
    }

    private func celebrate() {
        justFinishedNotes = true
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            justFinishedNotes = false
        }
    }

    func copyNotes() {
        guard let session = selected else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.markdown(), forType: .string)
    }
}
