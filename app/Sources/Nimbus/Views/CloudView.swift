import SwiftUI

/// A puffy cloud outline: overlapping circles over a rounded base.
struct CloudShape: Shape {
    /// Puffs as (x, y, radius): x and y are fractions of the width and height,
    /// radius is a fraction of the width. Shared with the app icon.
    static let puffs: [(CGFloat, CGFloat, CGFloat)] = [
        (0.18, 0.66, 0.14), (0.36, 0.46, 0.19), (0.58, 0.36, 0.23), (0.78, 0.52, 0.17), (0.88, 0.70, 0.11),
        // Bottom lumps
        (0.30, 0.86, 0.09), (0.55, 0.88, 0.10), (0.76, 0.86, 0.085),
    ]

    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        for (cx, cy, radius) in Self.puffs {
            p.addEllipse(in: CGRect(x: r.minX + cx * w - radius * w, y: r.minY + cy * h - radius * w,
                                    width: radius * 2 * w, height: radius * 2 * w))
        }
        p.addRoundedRect(in: CGRect(x: r.minX + 0.06 * w, y: r.minY + 0.55 * h, width: 0.88 * w, height: 0.37 * h),
                         cornerSize: CGSize(width: 0.18 * h, height: 0.18 * h))
        return p
    }
}

/// Nimbus himself. Breathes when idle, bobs with the teacher's voice while
/// listening, thinks with little dots, and smiles when notes are ready.
struct CloudMascot: View {
    var mood: AppModel.CloudMood
    var level: Float

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let lvl = CGFloat(level)
            let breathe = 1 + 0.025 * sin(t * 1.6) + (mood == .listening ? lvl * 0.06 : 0)
            let bob = mood == .listening ? sin(t * 5) * 1.5 * (0.4 + lvl) : sin(t * 1.2) * 2

            ZStack {
                CloudShape()
                    .fill(LinearGradient(colors: [.white, Color(red: 0.93, green: 0.96, blue: 1.0)],
                                         startPoint: .top, endPoint: .bottom))
                CloudShape()
                    .fill(.clear)
                    .glassEffect(.clear.tint(Theme.sky.opacity(mood == .listening ? 0.18 : 0.06)).interactive(),
                                 in: CloudShape())
                // Soft blue underside and a bright top edge make it look puffy.
                CloudShape()
                    .fill(LinearGradient(colors: [.clear, Theme.sky.opacity(0.28)], startPoint: .center, endPoint: .bottom))
                    .allowsHitTesting(false)
                CloudShape()
                    .stroke(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .center),
                            lineWidth: 2)
                    .blur(radius: 1)
                    .allowsHitTesting(false)
                face(t: t)
                    .offset(x: 2, y: 10)
                if mood == .thinking { thinkingDots(t: t).offset(y: -44) }
                if mood == .listening { recDot(t: t).offset(x: 38, y: -18) }
            }
            .scaleEffect(breathe)
            .offset(y: bob)
            .shadow(color: Theme.skyDeep.opacity(0.25), radius: 14, y: 8)
        }
    }

    @ViewBuilder
    private func face(t: TimeInterval) -> some View {
        let blink = (t.truncatingRemainder(dividingBy: 4.2)) < 0.14
        let look: CGFloat = mood == .listening ? CGFloat(sin(t * 0.9)) * 3 : 0
        VStack(spacing: 5) {
            HStack(spacing: 16) {
                eye(blink: blink, happy: mood == .done)
                eye(blink: blink, happy: mood == .done)
            }
            .offset(x: look)
            mouth(t: t)
        }
    }

    @ViewBuilder
    private func eye(blink: Bool, happy: Bool) -> some View {
        if happy {
            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.ink)
        } else {
            Capsule()
                .fill(Theme.ink)
                .frame(width: 7, height: blink ? 1.5 : 11)
        }
    }

    @ViewBuilder
    private func mouth(t: TimeInterval) -> some View {
        switch mood {
        case .listening:
            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { i in
                    let wave = abs(sin(t * 9 + Double(i) * 1.3))
                    Capsule()
                        .fill(Theme.skyDeep)
                        .frame(width: 3, height: 3 + CGFloat(level) * 10 * wave)
                }
            }
            .frame(height: 13)
        case .done:
            Capsule().fill(Theme.ink).frame(width: 14, height: 4)
                .overlay(Capsule().fill(Color.pink.opacity(0.7)).frame(width: 7, height: 2).offset(y: 1))
        default:
            Capsule().fill(Theme.ink.opacity(0.8)).frame(width: 9, height: 3)
        }
    }

    private func thinkingDots(t: TimeInterval) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.skyDeep)
                    .frame(width: 7, height: 7)
                    .offset(y: -4 * max(0, sin(t * 6 - Double(i) * 0.8)))
            }
        }
    }

    private func recDot(t: TimeInterval) -> some View {
        Circle()
            .fill(Color(red: 1, green: 0.33, blue: 0.38))
            .frame(width: 9, height: 9)
            .opacity(0.55 + 0.45 * sin(t * 4))
    }
}
