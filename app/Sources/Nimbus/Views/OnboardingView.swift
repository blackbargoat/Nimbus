import AVFoundation
import AppKit
import Speech
import SwiftUI
import UniformTypeIdentifiers

/// First launch: a few quick questions that build brain.md, then mic permission.
struct OnboardingView: View {
    @Bindable var model: AppModel

    @State private var step = 0
    @State private var grade = ""
    @State private var classes: [String] = []
    @State private var newClass = ""
    @State private var styles: Set<String> = ["Short bullets, one idea each", "Simple everyday words",
                                               "Use the teacher's own examples", "Explain big words simply"]
    @State private var sample = ""
    @State private var micReady = false

    private let styleOptions = [
        "Short bullets, one idea each", "Simple everyday words", "Use the teacher's own examples",
        "Explain big words simply", "Use = and -> shortcuts", "Start with a 2 line summary",
        "Bold the most important words", "Emojis are fine",
    ]
    private let classIdeas = ["Global Politics", "English", "Spanish", "Chemistry", "Biology", "History", "Math", "Physics"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Capsule().fill(i <= step ? Theme.ink : Theme.ink.opacity(0.12)).frame(height: 4)
                }
            }
            .padding(.horizontal, 30).padding(.top, 22)

            Group {
                switch step {
                case 0: welcome
                case 1: aboutYou
                case 2: noteStyle
                default: microphone
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(30)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }.buttonStyle(.glass)
                }
                Spacer()
                Button(step == 3 ? "Start using Nimbus" : step == 0 ? "Let's go" : "Next") {
                    if step == 3 { finish() } else { withAnimation(.spring(duration: 0.4)) { step += 1 } }
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.ink)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30).padding(.bottom, 24)
        }
        .frame(width: 640, height: 560)
        .background(Theme.backdrop)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            CloudMascot(mood: .done, level: 0).frame(width: 180, height: 130)
            Text("Hi, I'm Nimbus.").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text("Let's set up your brain so my notes sound like you.")
                .font(.system(size: 16)).foregroundStyle(Theme.ink.opacity(0.75))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("About you", "So I know what level to write at.")
            TextField("Grade and school, like Grade 11, IB Diploma", text: $grade)
                .textFieldStyle(.roundedBorder).controlSize(.large)
            Text("Your classes").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            HStack {
                TextField("Add a class and teacher, like Global Politics (Mr. Smith)", text: $newClass)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                    .onSubmit(addClass)
                Button("Add", action: addClass).buttonStyle(.glass)
            }
            FlowLayout(spacing: 8) {
                ForEach(classes, id: \.self) { c in
                    Button { classes.removeAll { $0 == c } } label: { Label(c, systemImage: "xmark") }
                        .buttonStyle(.glassProminent).tint(Theme.skyDeep)
                }
                ForEach(classIdeas.filter { idea in !classes.contains { $0.hasPrefix(idea) } }, id: \.self) { idea in
                    Button("+ \(idea)") { classes.append(idea) }.buttonStyle(.glass)
                }
            }
        }
    }

    private var noteStyle: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("How do you like notes?", "Pick what sounds like you.")
            FlowLayout(spacing: 8) {
                ForEach(styleOptions, id: \.self) { option in
                    let on = styles.contains(option)
                    Button {
                        if on { styles.remove(option) } else { styles.insert(option) }
                    } label: { Label(option, systemImage: on ? "checkmark" : "plus") }
                        .buttonStyle(.glassProminent)
                        .tint(on ? Theme.skyDeep : Color.white.opacity(0.6))
                        .foregroundStyle(on ? .white : Theme.ink)
                }
            }
            HStack {
                Text("Paste some of your own notes so I copy your style (optional)")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Import file") { importSample() }.buttonStyle(.glass)
            }
            TextEditor(text: $sample)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.85)))
                .frame(minHeight: 120)
        }
    }

    private var microphone: some View {
        VStack(spacing: 16) {
            Spacer()
            CloudMascot(mood: micReady ? .done : .listening, level: micReady ? 0 : 0.5).frame(width: 150, height: 108)
            Text(micReady ? "I can hear you!" : "Let me hear class")
                .font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text(micReady ? "Your brain is ready. I'll keep learning after every class."
                          : "Your Mac will ask for the microphone and speech recognition. Click Allow for both.")
                .multilineTextAlignment(.center)
                .font(.system(size: 15)).foregroundStyle(Theme.ink.opacity(0.75))
                .frame(maxWidth: 420)
            if !micReady {
                Button { Task { await askForMic() } } label: {
                    Label("Allow microphone", systemImage: "mic.fill").padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent).tint(Theme.skyDeep).controlSize(.large)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task { micReady = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            && SFSpeechRecognizer.authorizationStatus() == .authorized }
    }

    // MARK: Helpers

    private func title(_ text: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text(sub).font(.system(size: 15)).foregroundStyle(Theme.ink.opacity(0.7))
        }
    }

    private func addClass() {
        let c = newClass.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty, !classes.contains(c) else { return }
        classes.append(c)
        newClass = ""
    }

    private func importSample() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText, .text]
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        sample = String(text.prefix(6000))
    }

    private func askForMic() async {
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        withAnimation(.spring) { micReady = mic && speech == .authorized }
    }

    private func finish() {
        let ordered = styleOptions.filter { styles.contains($0) }
        model.finishOnboarding(brain: Brain.make(grade: grade, classes: classes, styles: ordered, sample: sample))
    }
}
