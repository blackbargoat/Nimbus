import SwiftUI

/// A rectangle with rounded corners drawn as pixel stairs, like a sprite.
struct PixelShape: InsettableShape {
    /// Size of one pixel step, in points.
    var step: CGFloat = 3
    /// Corner radius, in points. Stepped to the pixel grid.
    var radius: CGFloat = 12
    var inset: CGFloat = 0

    init(step: CGFloat = 3, radius: CGFloat = 12) {
        self.step = step
        self.radius = radius
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let rad = min(radius, r.width / 2, r.height / 2)
        let n = max(1, Int(rad / step))
        // How far each row of the corner is pulled in, from the top row down.
        let pulls: [CGFloat] = (0..<n).map { i in
            let y = rad - (CGFloat(i) + 0.5) * step
            return ((rad - sqrt(max(0, rad * rad - y * y))) / step).rounded() * step
        }
        var p = Path()
        // Top edge, then each corner as stairs, clockwise.
        p.move(to: CGPoint(x: r.minX + pulls[0], y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - pulls[0], y: r.minY))
        for i in 0..<n {
            p.addLine(to: CGPoint(x: r.maxX - pulls[i], y: r.minY + CGFloat(i) * step))
            p.addLine(to: CGPoint(x: r.maxX - pulls[i], y: r.minY + CGFloat(i + 1) * step))
        }
        for i in (0..<n).reversed() {
            p.addLine(to: CGPoint(x: r.maxX - pulls[i], y: r.maxY - CGFloat(i + 1) * step))
            p.addLine(to: CGPoint(x: r.maxX - pulls[i], y: r.maxY - CGFloat(i) * step))
        }
        p.addLine(to: CGPoint(x: r.minX + pulls[0], y: r.maxY))
        for i in 0..<n {
            p.addLine(to: CGPoint(x: r.minX + pulls[i], y: r.maxY - CGFloat(i) * step))
            p.addLine(to: CGPoint(x: r.minX + pulls[i], y: r.maxY - CGFloat(i + 1) * step))
        }
        for i in (0..<n).reversed() {
            p.addLine(to: CGPoint(x: r.minX + pulls[i], y: r.minY + CGFloat(i + 1) * step))
            p.addLine(to: CGPoint(x: r.minX + pulls[i], y: r.minY + CGFloat(i) * step))
        }
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> PixelShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// An 8-bit block with real thickness: a top face, a darker side underneath that
/// you can see (like a game button), and a soft shadow on the sky below it.
/// Pressed blocks sink down onto their side.
struct PixelBlock: ViewModifier {
    var fill: Color = .white
    var depth: CGFloat = 5
    var pressed = false
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        let shape = PixelShape(radius: radius)
        let sink = pressed ? depth - 1 : 0
        content
            .offset(y: sink)
            .background(
                ZStack {
                    // Soft shadow on the sky, for height.
                    shape.fill(Theme.shadow.opacity(pressed ? 0.12 : 0.22))
                        .offset(y: depth + 4)
                        .blur(radius: pressed ? 3 : 8)
                    // The side of the block.
                    shape.fill(Self.side(of: fill)).offset(y: depth)
                    // Top face with a bright top edge and a shaded bottom edge.
                    Rectangle().fill(fill)
                        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.8)).frame(height: 3) }
                        .overlay(alignment: .bottom) { Rectangle().fill(Self.side(of: fill).opacity(0.35)).frame(height: 3) }
                        .clipShape(shape)
                        .offset(y: sink)
                }
            )
            .padding(.bottom, depth)
    }

    /// The darker color for a block's side.
    static func side(of fill: Color) -> Color {
        fill.mix(with: Color(red: 0.12, green: 0.24, blue: 0.55), by: 0.42)
    }
}

extension View {
    func pixelBlock(_ fill: Color = .white, depth: CGFloat = 5, pressed: Bool = false, radius: CGFloat = 12) -> some View {
        modifier(PixelBlock(fill: fill, depth: depth, pressed: pressed, radius: radius))
    }
}

/// How a button's icon moves when you hover or click it.
enum GlyphMotion {
    case spin, wiggle, hop, pulse, slide, none

    static func `for`(_ symbol: String) -> GlyphMotion {
        switch symbol {
        case "arrow.clockwise", "gearshape", "plus", "hourglass": .spin
        case "brain.head.profile", "lightbulb.max.fill", "lightbulb.fill", "bubble.left.fill", "pin", "pin.fill": .wiggle
        case "mic.fill", "stop.fill", "waveform": .pulse
        case "doc.on.doc", "arrow.up", "arrow.right": .slide
        default: .hop
        }
    }
}

/// Plays a glyph's motion on hover, and again on every tap.
struct GlyphAnimation: ViewModifier {
    var motion: GlyphMotion
    var hovering: Bool
    var taps: Int

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(motion == .spin && hovering ? 90 : 0))
            .scaleEffect(motion == .pulse && hovering ? 1.15 : 1)
            .offset(y: motion == .hop && hovering ? -2 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.5), value: hovering)
            .keyframeAnimator(initialValue: Frame(), trigger: taps) { view, f in
                view.rotationEffect(.degrees(f.turn)).scaleEffect(f.scale).offset(x: f.dx, y: f.dy)
            } keyframes: { _ in
                KeyframeTrack(\.turn) {
                    switch motion {
                    case .spin: SpringKeyframe(360, duration: 0.5); CubicKeyframe(0, duration: 0.001)
                    case .wiggle: CubicKeyframe(-18, duration: 0.08); CubicKeyframe(16, duration: 0.1); CubicKeyframe(-10, duration: 0.1); SpringKeyframe(0, duration: 0.2)
                    default: CubicKeyframe(0, duration: 0.01)
                    }
                }
                KeyframeTrack(\.scale) {
                    switch motion {
                    case .pulse: CubicKeyframe(0.7, duration: 0.08); SpringKeyframe(1.25, duration: 0.15); SpringKeyframe(1, duration: 0.25)
                    default: CubicKeyframe(0.85, duration: 0.06); SpringKeyframe(1, duration: 0.3)
                    }
                }
                KeyframeTrack(\.dx) {
                    switch motion {
                    case .slide: CubicKeyframe(6, duration: 0.12); CubicKeyframe(-3, duration: 0.1); SpringKeyframe(0, duration: 0.2)
                    default: CubicKeyframe(0, duration: 0.01)
                    }
                }
                KeyframeTrack(\.dy) {
                    switch motion {
                    case .hop: CubicKeyframe(-6, duration: 0.12); SpringKeyframe(0, duration: 0.3)
                    case .slide: CubicKeyframe(-2, duration: 0.12); SpringKeyframe(0, duration: 0.2)
                    default: CubicKeyframe(0, duration: 0.01)
                    }
                }
            }
    }

    struct Frame {
        var turn: Double = 0
        var scale: CGFloat = 1
        var dx: CGFloat = 0
        var dy: CGFloat = 0
    }
}

extension View {
    func glyphMotion(_ motion: GlyphMotion, hovering: Bool, taps: Int) -> some View {
        modifier(GlyphAnimation(motion: motion, hovering: hovering, taps: taps))
    }
}

/// Hand-drawn 9x9 pixel icons. Falls back to an SF Symbol for anything not drawn.
struct Glyph: View {
    var name: String
    var size: CGFloat = 16
    /// Nil draws in the current foreground style, so .foregroundStyle works.
    var color: Color? = nil

    init(_ name: String, size: CGFloat = 16, color: Color? = nil) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        if let rows = Self.art[name] {
            Canvas { ctx, sz in
                let px = floor(sz.width / 9 * 2) / 2
                let o = (sz.width - px * 9) / 2
                for (y, row) in rows.enumerated() {
                    for (x, c) in row.enumerated() where c == "#" {
                        ctx.fill(Path(CGRect(x: o + CGFloat(x) * px, y: o + CGFloat(y) * px, width: px + 0.2, height: px + 0.2)),
                                 with: color.map { .color($0) } ?? .foreground)
                    }
                }
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: name).font(.system(size: size * 0.8, weight: .bold))
                .frame(width: size, height: size)
        }
    }

    /// Keyed by the SF Symbol name each one replaces.
    static let art: [String: [String]] = [
        "mic.fill": [
            "...###...", "..#####..", "..#####..", "..#####..", "#.#####.#", "#..###..#", ".#.....#.", "..#####..", "....#....",
        ],
        "stop.fill": [
            ".........", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".........",
        ],
        "hourglass": [
            "#########", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#####..", ".#######.", "#########",
        ],
        "doc.on.doc": [
            "#####....", "#...#....", "#.######.", "#.#....#.", "###.##.#.", "..#....#.", "..#.##.#.", "..#....#.", "..######.",
        ],
        "checkmark": [
            ".........", "........#", ".......##", "......##.", "#....##..", "##..##...", ".####....", "..##.....", ".........",
        ],
        "arrow.clockwise": [
            "..####.#.", ".#....##.", "#....###.", "#........", "#.......#", "#.......#", ".#.....#.", "..#####..", ".........",
        ],
        "plus": [
            ".........", "....#....", "....#....", "....#....", ".#######.", "....#....", "....#....", "....#....", ".........",
        ],
        "lightbulb.max.fill": [
            "...###...", "..#...#..", ".#.....#.", ".#..#..#.", "..#.#.#..", "...#.#...", "...###...", "...###...", "....#....",
        ],
        "note.text": [
            "#######..", "#.....##.", "#.###..##", "#.......#", "#.#####.#", "#.......#", "#.####..#", "#.......#", "#########",
        ],
        "waveform": [
            "....#....", "....#..#.", ".#..#..#.", ".#.##.##.", "##.#####.", ".#.##.##.", ".#..#..#.", "....#..#.", "....#....",
        ],
        "bubble.left.fill": [
            ".#######.", "#########", "#########", "#########", "#########", ".#######.", ".##......", ".#.......", ".........",
        ],
        "brain.head.profile": [
            "..####...", ".#....#..", "#..##..#.", "#.#..#.##", "#..##...#", "#......#.", ".#....#..", "..#..#...", "..#..#...",
        ],
        "gearshape": [
            "...#.#...", ".#.###.#.", "..#...#..", "##.....##", ".#..#..#.", "##.....##", "..#...#..", ".#.###.#.", "...#.#...",
        ],
        "point.3.connected.trianglepath.dotted": [
            "##.....##", "##.....##", "..#...#..", "...#.#...", "....#....", "....#....", "...###...", "...###...", ".........",
        ],
        "list.bullet": [
            ".........", "##.######", ".........", ".........", "##.######", ".........", ".........", "##.######", ".........",
        ],
        "text.alignleft": [
            ".........", "#######..", ".........", "#########", ".........", "#####....", ".........", "#######..", ".........",
        ],
        "calendar": [
            ".#.....#.", "#########", "#########", "#.......#", "#.#.#.#.#", "#.......#", "#.#.#.#.#", "#.......#", "#########",
        ],
        "clock": [
            "..#####..", ".#..#..#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", "#.......#", ".#.....#.", "..#####..",
        ],
        "record.circle": [
            "..#####..", ".#.....#.", "#..###..#", "#.#####.#", "#.#####.#", "#.#####.#", "#..###..#", ".#.....#.", "..#####..",
        ],
        "text.word.spacing": [
            ".........", "###.###.#", ".........", "##.####.#", ".........", "####.###.", ".........", "#.###....", ".........",
        ],
        "pin": [
            "..#####..", "..#...#..", "..#...#..", ".#######.", "....#....", "....#....", "....#....", "....#....", ".........",
        ],
        "pin.fill": [
            "..#####..", "..#####..", "..#####..", ".#######.", "....#....", "....#....", "....#....", "....#....", ".........",
        ],
        "xmark": [
            ".........", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#...#..", ".#.....#.", ".........",
        ],
        "ear.fill": [
            "..####...", ".#....#..", "#..##..#.", "#.#..#.#.", "....#..#.", "...#..#..", "...#.#...", "#..#.....", ".##......",
        ],
        "book.closed.fill": [
            ".#######.", ".#.....#.", ".#.###.#.", ".#.....#.", ".#.###.#.", ".#.....#.", ".#######.", ".#.......", ".#######.",
        ],
        "arrow.up": [
            "....#....", "...###...", "..#####..", ".#######.", "....#....", "....#....", "....#....", "....#....", "....#....",
        ],
        "arrow.right": [
            ".........", ".....#...", ".....##..", "#########", "#########", ".....##..", ".....#...", ".........", ".........",
        ],
        "questionmark.circle.fill": [
            "..#####..", ".#.....#.", "...###...", "......#..", ".....#...", "....#....", ".........", "....#....", ".........",
        ],
        "character.book.closed.fill": [
            ".#######.", ".#..#..#.", ".#.#.#.#.", ".#.###.#.", ".#.#.#.#.", ".#.....#.", ".#######.", ".#.......", ".#######.",
        ],
        "calendar.badge.exclamationmark": [
            ".#.....#.", "#########", "#########", "#.......#", "#...#...#", "#...#...#", "#.......#", "#...#...#", "#########",
        ],
        "exclamationmark.circle.fill": [
            "..#####..", ".#..#..#.", "#...#...#", "#...#...#", "#...#...#", "#.......#", "#...#...#", ".#.....#.", "..#####..",
        ],
        "arrow.triangle.branch": [
            ".........", "##.......", "..#......", "...####..", "......##.", "...####..", "..#......", "##.......", ".........",
        ],
        "tablecells": [
            "#########", "#...#...#", "#########", "#...#...#", "#########", "#...#...#", "#########", ".........", ".........",
        ],
        "lightbulb.fill": [
            "...###...", "..#...#..", ".#.....#.", ".#..#..#.", "..#.#.#..", "...#.#...", "...###...", "...###...", "....#....",
        ],
        "clock.arrow.circlepath": [
            "..#####..", ".#..#..#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", "#.......#", ".#.....#.", "..#####..",
        ],
        "bell.slash.fill": [
            "#...#....", ".#.###...", "..#####..", ".#.####..", ".##.###..", ".###.##..", "######.#.", "....#...#", ".........",
        ],
        "questionmark.bubble.fill": [
            ".#######.", "#..###..#", "#.....#.#", "#....#..#", "#...#...#", ".#######.", ".##......", ".#.......", ".........",
        ],
        "square": [
            ".........", ".#######.", ".#.....#.", ".#.....#.", ".#.....#.", ".#.....#.", ".#.....#.", ".#######.", ".........",
        ],
    ]
}
