import SwiftUI

struct SessionDetail: View {
    @Bindable var model: AppModel
    var session: ClassSession

    enum Tab: String, CaseIterable, Identifiable {
        case notes = "Notes", live = "Answers", transcript = "Transcript", ask = "Ask"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .notes: "note.text"
            case .live: "lightbulb.max.fill"
            case .transcript: "waveform"
            case .ask: "bubble.left.fill"
            }
        }
    }

    @State private var tab: Tab = Tab.allCases.first { "\($0)" == ProcessInfo.processInfo.environment["NIMBUS_DEMO_TAB"] } ?? .notes
    @State private var title = ""
    @Namespace private var tabSlide
    @State private var tabHover: Tab?
    @State private var tabTaps = 0

    private var isLive: Bool { model.recordingSessionID == session.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let message = model.message {
                banner(message)
            } else if !model.hasAI && !model.demo {
                banner("Add an AI key in Settings for notes and answers.")
            }
            HStack {
                tabs
                Spacer()
                if tab == .notes { NoteStylePicker(model: model) }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Class name", text: $title)
                    .textFieldStyle(.plain)
                    .font(Theme.display(28, 700))
                    .foregroundStyle(Theme.ink)
                    .onSubmit { model.rename(session.id, to: title) }
                    .onChange(of: title) { _, new in model.rename(session.id, to: new) }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let time = isLive ? model.elapsed(at: ctx.date) : session.duration
                    HStack(spacing: 6) {
                        chip("calendar", session.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        chip(isLive ? "record.circle" : "clock", ClassSession.clock(time), live: isLive)
                        chip("text.word.spacing", "\(session.wordCount)")
                    }
                }
            }
            Spacer(minLength: 12)

            // Everything you do to a class, in one cluster.
            HStack(spacing: 8) {
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy notes for Google Docs") { model.copyNotes() }
                    .disabled(session.notes == nil)
                    .opacity(session.notes == nil ? 0.4 : 1)
                IconButton(symbol: "arrow.clockwise", help: "Rewrite notes now") {
                    Task { await model.updateNotes(session.id) }
                }
                .disabled(session.lines.isEmpty || model.isUpdatingNotes)
                .opacity(session.lines.isEmpty ? 0.4 : 1)
                .rotationEffect(.degrees(model.isUpdatingNotes ? 360 : 0))
                .animation(model.isUpdatingNotes ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                           value: model.isUpdatingNotes)
                MicButton(model: model, isLive: isLive, size: 46) {
                    model.selectedID = session.id
                    model.toggleRecording()
                }
                .disabled(model.isStarting || (model.isRecording && !isLive))
            }
        }
        // Title, stats, and actions share one panel so nothing floats loose over the clouds.
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .raised(PixelShape(), fill: Color(red: 0.97, green: 0.98, blue: 1))
        .padding(.horizontal, 22)
        .padding(.top, 40)
    }

    private var copied: Bool { model.copiedAt != nil }

    private func chip(_ symbol: String, _ text: String, live: Bool = false) -> some View {
        HStack(spacing: 5) {
            Glyph(symbol, size: 13)
                .foregroundStyle(live ? Theme.rec : Theme.skyDeep)
            Text(text).font(Theme.body(12, 700).monospacedDigit()).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 9).frame(height: 24)
        .background(PixelShape(radius: 6).fill(Theme.skyMist))
    }

    /// Icon tabs. The picked one opens up to show its name.
    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                let on = tab == t
                Button {
                    tabTaps += 1
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Glyph(t.symbol, size: 16)
                            .glyphMotion(.for(t.symbol), hovering: tabHover == t, taps: on ? tabTaps : 0)
                        if on { Text(t.rawValue).font(Theme.body(13, 700)).fixedSize() }
                    }
                    .foregroundStyle(on ? .white : Theme.ink)
                    .padding(.horizontal, on ? 14 : 11)
                    .frame(height: 34)
                    .background {
                        // The dark highlight slides over to the tab you pick.
                        if on { PixelShape(radius: 9).fill(Theme.ink).matchedGeometryEffect(id: "tab", in: tabSlide) }
                    }
                    .contentShape(PixelShape())
                }
                .buttonStyle(.plain)
                .onHover { tabHover = $0 ? t : (tabHover == t ? nil : tabHover) }
                .help(t.rawValue)
            }
        }
        .padding(4)
        .raised(PixelShape(), lift: 0.7)
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Glyph( "exclamationmark.circle.fill").foregroundStyle(Theme.sunInk)
            Text(text).font(Theme.body(13, 600)).foregroundStyle(Theme.ink)
            Spacer()
            if model.message != nil {
                Button { model.message = nil } label: { Glyph( "xmark").font(.system(size: 11, weight: .bold)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(PixelShape().fill(Color(red: 1, green: 0.96, blue: 0.88)))
        .overlay(PixelShape().strokeBorder(Theme.sun.opacity(0.4)))
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }
}
