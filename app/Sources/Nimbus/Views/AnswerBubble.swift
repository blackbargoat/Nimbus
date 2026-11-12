import AppKit
import SwiftUI

/// The speech bubble that pops up beside the cloud with a live answer.
final class AnswerPanel: NSPanel {
    static let size = NSSize(width: 420, height: 460)

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
        VStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Glyph( "ear.fill").foregroundStyle(Theme.skyDeep)
                    Text(a.question)
                        .font(Theme.body(12.5, 700))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if a.isDone {
                        small(model.bubblePinned ? "pin.fill" : "pin", help: model.bubblePinned ? "Unpin" : "Keep this up") { model.togglePin() }
                        small("doc.on.doc", help: "Copy answer") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(a.answer.replacingOccurrences(of: "**", with: ""), forType: .string)
                        }
                    }
                    small("xmark", help: "Close") { model.dismissBubble() }
                }

                ScrollView {
                    Group {
                        // Hide the reply while it might still turn out to be "SKIP".
                        if a.answer.isEmpty || (!a.isDone && "SKIP".hasPrefix(a.answer.trimmingCharacters(in: .whitespaces))) {
                            ThinkingDots().frame(height: 22)
                        } else {
                            RichText(a.answer, size: 15)
                                .textSelection(.enabled)
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
                .fixedSize(horizontal: false, vertical: true)

                countdown
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(width: 370)
            .pixelBlock(.white, depth: 6)

            // The little thought bubbles trailing down to Nimbus.
            VStack(spacing: 3) {
                PixelShape(step: 2).fill(.white).frame(width: 16, height: 16)
                PixelShape(step: 2).fill(.white).frame(width: 9, height: 9).offset(x: -6)
            }

        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .onHover { inside in
            if inside { model.keepBubble() } else { model.releaseBubble() }
        }
    }

    /// A bar that shrinks until the bubble floats away. Hover or pin to stop it.
    @ViewBuilder
    private var countdown: some View {
        if let deadline = model.bubbleDeadline {
            TimelineView(.animation(minimumInterval: 0.25)) { ctx in
                let left = max(0, deadline.timeIntervalSince(ctx.date) / model.bubbleLifetime)
                GeometryReader { g in
                    PixelShape().fill(Theme.skyMist)
                        .overlay(alignment: .leading) {
                            PixelShape().fill(Theme.sky).frame(width: g.size.width * left)
                        }
                }
                .frame(height: 3)
            }
        } else if model.bubblePinned {
            PixelShape().fill(Theme.skyDeep).frame(height: 3)
        }
    }

    private func small(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Glyph( symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 24, height: 24)
                .background(PixelShape(step: 2).fill(Theme.skyMist))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// A puffy thought-cloud outline: a rounded body with bumps all the way around.
struct ThoughtCloudShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let inset: CGFloat = 12
        let body = r.insetBy(dx: inset, dy: inset)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: 26, height: 26))
        func bumps(from a: CGPoint, to b: CGPoint, radius: CGFloat) {
            let length = hypot(b.x - a.x, b.y - a.y)
            let count = max(2, Int(length / (radius * 1.5)))
            for i in 0...count {
                let t = CGFloat(i) / CGFloat(count)
                let wobble: CGFloat = i.isMultiple(of: 2) ? 1 : 0.8
                let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let rr = radius * wobble
                p.addEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
            }
        }
        let k: CGFloat = 20
        bumps(from: CGPoint(x: body.minX + k, y: body.minY + 6), to: CGPoint(x: body.maxX - k, y: body.minY + 6), radius: 22)
        bumps(from: CGPoint(x: body.minX + k, y: body.maxY - 6), to: CGPoint(x: body.maxX - k, y: body.maxY - 6), radius: 18)
        bumps(from: CGPoint(x: body.minX + 6, y: body.minY + k), to: CGPoint(x: body.minX + 6, y: body.maxY - k), radius: 18)
        bumps(from: CGPoint(x: body.maxX - 6, y: body.minY + k), to: CGPoint(x: body.maxX - 6, y: body.maxY - k), radius: 18)
        return p
    }
}

/// Three dots bouncing while Nimbus thinks of an answer.
struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    PixelShape(step: 2)
                        .fill(Theme.skyDeep)
                        .frame(width: 8, height: 8)
                        .offset(y: -5 * max(0, sin(t * 6 - Double(i) * 0.8)))
                }
                Text("thinking").font(Theme.body(13, 700)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
