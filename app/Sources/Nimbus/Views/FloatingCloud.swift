import AppKit
import SwiftUI

/// The always-on-top cloud that sits on the desktop during class.
final class CloudPanel: NSPanel {
    init(model: AppModel, openMain: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 130),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false

        let root = FloatingCloud(model: model, openMain: openMain) { [weak self] in
            self?.frame.origin ?? .zero
        } setOrigin: { [weak self] origin in
            self?.setFrameOrigin(origin)
        } onDragEnd: { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(NSStringFromPoint(self.frame.origin), forKey: "cloudOrigin")
        }
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        contentView = host

        if let saved = UserDefaults.standard.string(forKey: "cloudOrigin") {
            setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: screen.maxX - 210, y: screen.minY + 30))
        }
    }

    override var canBecomeKey: Bool { false }
}

struct FloatingCloud: View {
    @Bindable var model: AppModel
    var openMain: () -> Void
    var origin: () -> NSPoint
    var setOrigin: (NSPoint) -> Void
    var onDragEnd: () -> Void

    @State private var hovering = false
    /// Mouse and window positions (screen coordinates) when the drag began.
    @State private var dragStart: (mouse: NSPoint, window: NSPoint)?

    var body: some View {
        VStack(spacing: 6) {
            CloudMascot(mood: model.mood, level: model.level)
                .frame(width: 128, height: 92)
                .scaleEffect(0.6)
                .frame(width: 78, height: 56)
                .contentShape(CloudShape())
                .onTapGesture(perform: openMain)
                .gesture(drag)
                .help("Click to open your notes. Drag to move me.")

            if hovering || model.isRecording || model.isStarting || model.demo {
                controls.transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.bottom, 12)
        .frame(width: 200, height: 130, alignment: .bottom)
        .onHover { h in withAnimation(.spring(duration: 0.3)) { hovering = h } }
        .contextMenu {
            Button(model.isRecording ? "Stop listening" : "Start listening") { model.toggleRecording() }
            Button("Help me answer") { model.helpMeAnswer() }.disabled(!model.isRecording)
            Button("Open Nimbus", action: openMain)
            Divider()
            Button("Quit Nimbus") { NSApp.terminate(nil) }
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            round(model.isRecording || model.demo ? "stop.fill" : "mic.fill",
                  fill: model.isRecording || model.demo ? Theme.rec : Theme.ink,
                  help: model.isRecording ? "Stop listening" : "Start listening") { model.toggleRecording() }

            if model.isRecording || model.demo {
                round("lightbulb.max.fill", fill: Theme.sun, help: "Help me answer") { model.helpMeAnswer() }
                    .disabled(model.isAnswering)
                    .opacity(model.isAnswering ? 0.5 : 1)

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(model.demo && !model.isRecording ? "12:48" : ClassSession.clock(model.elapsed(at: ctx.date)))
                        .font(Theme.body(12, 750).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(5)
        .raised(PixelShape(), lift: 0.6)
        .shadow(color: Color(red: 0.1, green: 0.25, blue: 0.5).opacity(0.15), radius: 8, y: 3)
    }

    private func round(_ symbol: String, fill: Color, help: String, action: @escaping () -> Void) -> some View {
        FloatingButton(symbol: model.isStarting && symbol == "mic.fill" ? "hourglass" : symbol, fill: fill, action: action)
            .help(help)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { _ in
                let mouse = NSEvent.mouseLocation
                if dragStart == nil { dragStart = (mouse, origin()) }
                guard let start = dragStart else { return }
                setOrigin(NSPoint(x: start.window.x + mouse.x - start.mouse.x,
                                  y: start.window.y + mouse.y - start.mouse.y))
            }
            .onEnded { _ in
                dragStart = nil
                onDragEnd()
            }
    }
}

/// A small 3D pixel button for the floating cloud.
private struct FloatingButton: View {
    var symbol: String
    var fill: Color
    var action: () -> Void
    @State private var hover = false
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Glyph(symbol, size: 15, color: .white)
                .glyphMotion(.for(symbol), hovering: hover, taps: taps)
                .frame(width: 30, height: 28)
        }
        .buttonStyle(PixelPress(fill: fill, depth: 4))
        .onHover { hover = $0 }
    }
}
