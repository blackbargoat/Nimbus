import SwiftUI

extension Notification.Name {
    static let showBrain = Notification.Name("NimbusShowBrain")
}

struct MainView: View {
    @Bindable var model: AppModel
    @State private var showSettings = false
    @State private var showBrain = false

    var body: some View {
        ZStack {
            SkyBackdrop()
            HStack(spacing: 0) {
                // Starts below the window's close/minimize buttons so nothing overlaps them.
                Sidebar(model: model, showBrain: $showBrain, showSettings: $showSettings)
                    .frame(width: 236)
                    .padding(.leading, 12)
                    .padding(.top, 40)
                    .padding(.bottom, 14)
                if let session = model.selected {
                    SessionDetail(model: model, session: session)
                        .id(session.id)
                } else {
                    EmptyHome(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showBrain) { BrainView(model: model) }
        .onReceive(NotificationCenter.default.publisher(for: .showBrain)) { _ in showBrain = true }
        .sheet(isPresented: Binding(get: { model.needsOnboarding && !model.demo }, set: { _ in })) {
            OnboardingView(model: model).interactiveDismissDisabled()
        }
        .tint(Theme.skyDeep)
    }
}

private struct Sidebar: View {
    @Bindable var model: AppModel
    @Binding var showBrain: Bool
    @Binding var showSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Nimbus himself, showing how he feels right now.
                MascotBadge(mood: model.mood, level: model.level, size: 50)
                Text("Nimbus").font(Theme.display(20, 700)).foregroundStyle(Theme.ink)
                Spacer()
                IconButton(symbol: "plus", help: "New class") { model.newSession() }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.sessions) { s in
                        row(s)
                    }
                }
                .padding(.horizontal, 10)
            }

            HStack(spacing: 8) {
                IconButton(symbol: "brain.head.profile", help: "Nimbus Brain: how you like notes") { showBrain = true }
                IconButton(symbol: "gearshape", help: "Settings") { showSettings = true }
                Spacer()
            }
            .padding(16)
        }
        .raised(PixelShape(), fill: Color(red: 0.97, green: 0.98, blue: 1), lift: 1.2)
    }

    private func row(_ s: ClassSession) -> some View {
        let selected = model.selectedID == s.id
        return Button { model.selectedID = s.id } label: {
            HStack(spacing: 10) {
                ZStack {
                    PixelShape()
                        .fill(selected ? Theme.skyDeep : Theme.skyMist)
                    Glyph( model.recordingSessionID == s.id ? "waveform" : "book.closed.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.skyDeep)
                        .symbolEffect(.variableColor.iterative, isActive: model.recordingSessionID == s.id)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.displayTitle)
                        .font(Theme.body(13.5, 700))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(s.createdAt.formatted(.dateTime.month(.abbreviated).day()) + "  " + ClassSession.clock(s.duration))
                        .font(Theme.body(11.5, 600).monospacedDigit())
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background {
                if selected {
                    Color.clear.raised(PixelShape(), lift: 0.4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete class", role: .destructive) { model.delete(s.id) }
        }
    }
}

private struct EmptyHome: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            CloudMascot(mood: .idle, level: 0).frame(width: 220, height: 176)
            Text("Hi, I'm Nimbus").font(Theme.display(40, 700)).foregroundStyle(Theme.ink)
            MicButton(model: model, isLive: false, size: 76) {
                model.newSession()
                model.toggleRecording()
            }
        }
        .padding(40)
    }
}

/// The big mic: a chunky 3D pixel button. Black when idle, red with a pulsing
/// ring that follows the teacher's voice while listening.
struct MicButton: View {
    var model: AppModel
    var isLive: Bool
    var size: CGFloat = 56
    var action: () -> Void
    @State private var hover = false
    @State private var taps = 0

    var body: some View {
        let symbol = model.isStarting && isLive ? "hourglass" : isLive ? "stop.fill" : "mic.fill"
        Button {
            taps += 1
            action()
        } label: {
            Glyph(symbol, size: size * 0.42, color: .white)
                .glyphMotion(.for(symbol), hovering: hover, taps: taps)
                .frame(width: size, height: size - 6)
        }
        .buttonStyle(PixelPress(fill: isLive ? Theme.rec : Theme.ink, depth: 6))
        .overlay {
            if isLive {
                PixelShape()
                    .stroke(Theme.rec.opacity(0.5), lineWidth: 3)
                    .padding(-4 - CGFloat(model.level) * 8)
                    .animation(.easeOut(duration: 0.15), value: model.level)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(hover ? 1.05 : 1)
        .animation(.spring(duration: 0.25, bounce: 0.5), value: hover)
        .onHover { hover = $0 }
        .help(isLive ? "Stop listening" : "Start listening")
    }
}
