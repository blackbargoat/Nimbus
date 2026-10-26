import AppKit
import SwiftUI

/// The speech bubble that pops up beside the cloud with a live answer.
final class AnswerPanel: NSPanel {
    static let size = NSSize(width: 360, height: 250)

    init(model: AppModel) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        let host = NSHostingView(rootView: AnswerBubble(model: model))
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }

    /// Sits above the cloud, or beside it when the cloud is near the top of the screen.
    func place(near cloud: NSRect) {
        let screen = (NSScreen.screens.first { $0.frame.intersects(cloud) } ?? NSScreen.main)?.visibleFrame ?? cloud
        var origin = NSPoint(x: cloud.midX - Self.size.width / 2, y: cloud.maxY - 8)
        if origin.y + Self.size.height > screen.maxY {
            origin.y = cloud.midY - Self.size.height / 2
            origin.x = cloud.minX - Self.size.width + 10
            if origin.x < screen.minX { origin.x = cloud.maxX - 10 }
        }
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - Self.size.width - 8)
        origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - Self.size.height - 8)
        setFrameOrigin(origin)
    }
}

struct AnswerBubble: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let answer = model.liveAnswer {
                card(answer)
                    .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: AnswerPanel.size.width, height: AnswerPanel.size.height, alignment: .bottom)
        .animation(.spring(duration: 0.35), value: model.liveAnswer?.id)
    }

    private func card(_ a: LiveAnswer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.max.fill").foregroundStyle(Theme.sun)
                Text("Teacher asked").font(.system(size: 11, weight: .bold)).textCase(.uppercase)
                    .foregroundStyle(Theme.skyDeep)
                Spacer()
                if a.isDone {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(a.answer, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain)
                        .help("Copy answer")
                }
                Button { model.dismissBubble() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help("Close")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)

            Text("\u{201C}\(a.question)\u{201D}")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)

            ScrollView {
                Group {
                    if a.answer.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Thinking of an answer...").font(.system(size: 13))
                        }
                    } else {
                        Text(LocalizedStringKey(a.answer))
                            .font(.system(size: 14))
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    }
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassEffect(.regular.tint(.white.opacity(0.55)), in: .rect(cornerRadius: 22))
        .shadow(color: Theme.skyDeep.opacity(0.2), radius: 16, y: 6)
        .padding(10)
        .onHover { inside in
            if inside { model.keepBubble() } else if a.isDone { model.scheduleBubbleHide(a.id, after: 20) }
        }
    }
}
