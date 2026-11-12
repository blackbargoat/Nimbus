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

/// Nimbus as 8-bit pixel art, to match the pixel sky. Same moods as before:
/// breathes when idle, mouth bars move with the teacher's voice while listening,
/// thought dots while thinking, happy eyes when notes are ready, and a worried
/// face when something went wrong.
struct CloudMascot: View {
    var mood: AppModel.CloudMood
    var level: Float

    /// Grid size in art pixels. The top 4 rows are sky, for the thought dots.
    static let cols = 30, rows = 24, top = 4

    private enum Ink { case fringe, body, shade, deep, ground }

    /// The cloud body, worked out once from CloudShape. Shaded like the clouds in the
    /// sky art: white core, a dithered light-blue fringe instead of an outline, a blue
    /// belly, and a soft pixel shadow underneath so he floats.
    private static let art: [(Int, Int, Ink)] = {
        let bodyRows = rows - top
        let shape = CloudShape().path(in: CGRect(x: 1, y: 1, width: CGFloat(cols - 2), height: CGFloat(bodyRows - 2)))
        func inside(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && y >= 0 && x < cols && y < bodyRows && shape.contains(CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5))
        }
        var out: [(Int, Int, Ink)] = []
        for y in 0..<bodyRows {
            for x in 0..<cols {
                let edge = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { !inside(x + $0.0, y + $0.1) }
                if inside(x, y) {
                    let ink: Ink = !inside(x, y + 1) ? .deep
                        : (!inside(x, y + 3) || y > bodyRows - 6) ? .shade
                        : edge ? .fringe : .body
                    out.append((x, y + top, ink))
                }
            }
        }
        return out
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let px = min(size.width / CGFloat(Self.cols), size.height / CGFloat(Self.rows))
                let ox = (size.width - px * CGFloat(Self.cols)) / 2
                // Bob in whole art pixels, like an old game sprite.
                let bobRate = mood == .listening ? 4.0 : 1.4
                let bob = CGFloat((sin(t * bobRate) > 0.3 ? 1 : 0) + (mood == .listening && level > 0.25 ? 1 : 0))
                let oy = (size.height - px * CGFloat(Self.rows)) / 2 - bob * px * 0.5
                func dot(_ x: Int, _ y: Int, _ color: Color) {
                    ctx.fill(Path(CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px, width: px + 0.3, height: px + 0.3)),
                             with: .color(color))
                }
                // Shadow on the "ground", left behind when he bobs up.
                for x in 6..<(Self.cols - 6) where (x + Int(bob)) % 2 == 0 || (x > 9 && x < Self.cols - 9) {
                    ctx.fill(Path(CGRect(x: ox + CGFloat(x) * px, y: (size.height - px * CGFloat(Self.rows)) / 2 + CGFloat(Self.rows - 1) * px + px * 0.6,
                                         width: px + 0.3, height: px * 0.8)),
                             with: .color(Pixel.ground.opacity(0.35 - Double(bob) * 0.1)))
                }
                for (x, y, ink) in Self.art {
                    switch ink {
                    case .fringe: dot(x, y, (x + y).isMultiple(of: 2) ? Pixel.light : Pixel.fringe)
                    case .body: dot(x, y, .white)
                    case .shade: dot(x, y, (x + y).isMultiple(of: 2) ? Pixel.shade : .white)
                    case .deep: dot(x, y, Pixel.shade)
                    case .ground: break
                    }
                }
                face(t: t, dot: dot)
            }
        }
        .accessibilityLabel("Nimbus")
    }

    /// Eyes, mouth, and extras, drawn as pixel patterns.
    private func face(t: TimeInterval, dot: (Int, Int, Color) -> Void) {
        let eyeY = 14, leftX = 12, rightX = 17, mouthY = 17
        let blink = t.truncatingRemainder(dividingBy: 4.2) < 0.15
        let ink = Pixel.ink

        switch mood {
        case .done:
            // ^ ^ eyes, a smile, rosy cheeks.
            for x in [leftX, rightX] { dot(x - 1, eyeY + 1, ink); dot(x, eyeY, ink); dot(x + 1, eyeY + 1, ink) }
            dot(13, mouthY, ink); dot(16, mouthY, ink); dot(14, mouthY + 1, ink); dot(15, mouthY + 1, ink)
            dot(10, eyeY + 2, Pixel.cheek); dot(19, eyeY + 2, Pixel.cheek)
        case .oops:
            // Worried: slanted brows and a wobbly mouth.
            dot(leftX - 1, eyeY - 2, ink); dot(leftX, eyeY - 1, ink)
            dot(rightX + 1, eyeY - 2, ink); dot(rightX, eyeY - 1, ink)
            for x in [leftX, rightX] { dot(x, eyeY, ink); dot(x, eyeY + 1, ink) }
            dot(13, mouthY + 1, ink); dot(14, mouthY, ink); dot(15, mouthY, ink); dot(16, mouthY + 1, ink)
        default:
            // Round eyes that look up while thinking and side to side while listening.
            let look = mood == .listening ? (sin(t * 0.9) > 0 ? 1 : 0) : 0
            let up = mood == .thinking ? -1 : 0
            for x in [leftX, rightX] {
                if blink {
                    dot(x + look, eyeY + 1, ink)
                } else {
                    dot(x + look, eyeY + up, ink); dot(x + look, eyeY + 1 + up, ink)
                }
            }
            switch mood {
            case .listening:
                // Voice bars that jump with the mic level.
                for i in 0..<4 {
                    let wave = abs(sin(t * 9 + Double(i) * 1.3))
                    let h = 1 + Int((Double(level) * 3.5 * wave).rounded())
                    for k in 0..<min(h, 3) { dot(13 + i, mouthY + 1 - k, Pixel.voice) }
                }
            case .thinking:
                dot(14, mouthY, ink); dot(15, mouthY, ink)
                // Three dots hopping above his head.
                for i in 0..<3 {
                    let hop = sin(t * 6 - Double(i) * 0.8) > 0.2 ? 1 : 0
                    dot(11 + i * 4, 2 - hop, Pixel.voice); dot(12 + i * 4, 2 - hop, Pixel.voice)
                    dot(11 + i * 4, 3 - hop, Pixel.voice); dot(12 + i * 4, 3 - hop, Pixel.voice)
                }
            default:
                dot(14, mouthY, ink); dot(15, mouthY, ink)
            }
        }
        if mood == .listening, sin(t * 4) > -0.2 {
            // Little red "on air" light.
            dot(24, 7, Theme.rec); dot(25, 7, Theme.rec); dot(24, 8, Theme.rec); dot(25, 8, Theme.rec)
        }
    }
}

/// The pixel palette, pulled from the sky art so Nimbus belongs in it.
enum Pixel {
    static let fringe = Color(red: 0.66, green: 0.78, blue: 0.95)
    static let shade = Color(red: 0.74, green: 0.83, blue: 0.96)
    static let light = Color(red: 0.84, green: 0.90, blue: 0.98)
    static let ground = Color(red: 0.16, green: 0.3, blue: 0.62)
    /// The hard block shadow under every panel and button.
    static let drop = Color(red: 0.24, green: 0.40, blue: 0.74)
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.24)
    static let voice = Color(red: 0.16, green: 0.45, blue: 0.91)
    static let cheek = Color(red: 1.0, green: 0.62, blue: 0.72)
}

/// Nimbus on his own little patch of sky, so he stands out at small sizes
/// and never ends up white-on-white.
struct MascotBadge: View {
    var mood: AppModel.CloudMood
    var level: Float = 0
    var size: CGFloat = 56

    var body: some View {
        CloudMascot(mood: mood, level: level)
            .frame(width: size * 0.92, height: size * 0.74)
            .frame(width: size, height: size * 0.86)
            .pixelBlock(Color(red: 0.42, green: 0.62, blue: 0.93), depth: 4, radius: 9)
    }
}
