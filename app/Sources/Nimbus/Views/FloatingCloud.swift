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

            if hovering || model.isRecording || model.isStarting {
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
        HStack(spacing: 8) {
            Button {
                model.toggleRecording()
            } label: {
                Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.glassProminent)
            .tint(model.isRecording ? Color(red: 1, green: 0.36, blue: 0.42) : Theme.skyDeep)
            .buttonBorderShape(.circle)

            if model.isRecording {
                Button {
                    model.helpMeAnswer()
                } label: {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.sun)
                .buttonBorderShape(.circle)
                .help("Help me answer what the teacher just asked")
                .disabled(model.isAnswering)
            }

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(model.isStarting ? "Getting ready" : model.isRecording
                     ? ClassSession.clock(model.elapsed(at: ctx.date)) : "Listen")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .padding(.trailing, 6)
        }
        .padding(4)
        .glassEffect(.regular.tint(.white.opacity(0.4)), in: .capsule)
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
