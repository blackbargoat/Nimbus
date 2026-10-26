import SwiftUI

struct SessionDetail: View {
    @Bindable var model: AppModel
    var session: ClassSession

    enum Tab: String, CaseIterable, Identifiable {
        case notes = "Notes", live = "Live answers", transcript = "Transcript", ask = "Ask Nimbus"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .notes: "list.bullet.rectangle"
            case .live: "lightbulb.max"
            case .transcript: "text.quote"
            case .ask: "bubble.left.and.text.bubble.right"
            }
        }
    }

    @State private var tab: Tab = .notes
    @State private var title = ""

    private var isLive: Bool { model.recordingSessionID == session.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let message = model.message {
                banner(message)
            } else if !model.hasAI {
                banner("I'll still write down everything I hear. Add a Google or Claude API key in Settings (gear, top right) for notes and live answers.")
            }
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 560)
            .padding(.vertical, 12)

            Group {
                switch tab {
                case .notes: NotesView(model: model, session: session)
                case .live: LiveAnswersView(model: model, session: session, isLive: isLive)
                case .transcript: TranscriptView(model: model, session: session, isLive: isLive)
                case .ask: AskView(model: model, session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { title = session.title }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Class name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .onSubmit { model.rename(session.id, to: title) }
                    .onChange(of: title) { _, new in model.rename(session.id, to: new) }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let time = isLive ? model.elapsed(at: ctx.date) : session.duration
                    Text("\(session.createdAt.formatted(date: .complete, time: .shortened))  ·  \(ClassSession.clock(time))  ·  \(session.wordCount) words")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()

            Button {
                model.copyNotes()
            } label: { Label("Copy notes", systemImage: "doc.on.doc") }
                .buttonStyle(.glass)
                .disabled(session.notes == nil)
                .help("Copies the notes as text you can paste into Google Docs")

            Button {
                Task { await model.updateNotes(session.id) }
            } label: { Label("Update notes", systemImage: "sparkles") }
                .buttonStyle(.glass)
                .disabled(session.lines.isEmpty || model.isUpdatingNotes)

            Button {
                model.selectedID = session.id
                model.toggleRecording()
            } label: {
                Label(model.isStarting && isLive ? "Getting ready" : isLive ? "Stop" : (session.lines.isEmpty ? "Listen" : "Keep listening"),
                      systemImage: model.isStarting && isLive ? "hourglass" : isLive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(isLive ? Color(red: 1, green: 0.36, blue: 0.42) : Theme.ink)
            .controlSize(.large)
            .disabled(model.isStarting || (model.isRecording && !isLive))
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private func banner(_ text: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(Theme.sun)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.ink)
            Spacer()
            if model.message != nil {
                Button { model.message = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(Theme.sun.opacity(0.15)), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 28)
        .padding(.top, 10)
    }
}
