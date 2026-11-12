import AppKit
import CoreText
import SwiftUI

enum Theme {
    static let sky = Color(red: 0.36, green: 0.62, blue: 0.95)
    static let skyDeep = Color(red: 0.13, green: 0.45, blue: 0.91)
    static let skyMist = Color(red: 0.91, green: 0.95, blue: 1.0)
    static let ink = Color(red: 0.05, green: 0.08, blue: 0.14)
    static let inkSoft = Color(red: 0.27, green: 0.33, blue: 0.44)
    static let line = Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.08)
    static let paper = Color(red: 0.965, green: 0.972, blue: 0.984)
    static let sun = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let sunInk = Color(red: 0.62, green: 0.36, blue: 0.0)
    static let rec = Color(red: 1, green: 0.36, blue: 0.42)
    /// Shadows are deep sky blue, not grey, so they sit in the scene.
    static let shadow = Color(red: 0.08, green: 0.2, blue: 0.48)

    /// Daytime sky: blue at the top, almost white at the bottom.
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.42, green: 0.64, blue: 0.94), Color(red: 0.63, green: 0.79, blue: 0.98),
                 Color(red: 0.86, green: 0.92, blue: 0.99), Color(red: 0.95, green: 0.97, blue: 1.0)],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: Type

    /// Jersey 10 for headings and labels (8-bit, to match the sky), Nunito for reading.
    /// Both are variable fonts shipped in Resources/Fonts.
    static func display(_ size: CGFloat, _ weight: CGFloat = 700) -> Font {
        // Jersey 10 is compact, so it runs a bit larger than the size asked for.
        font(Fonts.display, size: (size * 1.3).rounded(), weight: weight, fallback: .rounded)
    }

    static func body(_ size: CGFloat, _ weight: CGFloat = 500) -> Font {
        font(Fonts.body, size: size, weight: weight, fallback: .rounded)
    }

    private static func font(_ descriptor: CTFontDescriptor?, size: CGFloat, weight: CGFloat, fallback: Font.Design) -> Font {
        guard let descriptor else { return .system(size: size, weight: weight >= 650 ? .bold : .medium, design: fallback) }
        let varied = CTFontDescriptorCreateCopyWithAttributes(descriptor, [
            kCTFontVariationAttribute: [NSNumber(value: Fonts.wght): NSNumber(value: Double(weight))],
        ] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(varied, size, nil))
    }
}

/// Loads bundled resources. `swift run` falls back to the source folder.
enum Bundled {
    static func url(_ name: String) -> URL? {
        var candidates = [Bundle.main.resourceURL?.appendingPathComponent(name)]
        // Debug only: a release build must not carry the build machine's source path.
        #if DEBUG
        candidates.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../Resources/\(name)").standardized)
        #endif
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

enum Fonts {
    static let wght = 0x7767_6874

    static let display = load("Jersey10")
    static let body = load("Nunito")

    private static func load(_ name: String) -> CTFontDescriptor? {
        guard let url = Bundled.url("Fonts/\(name).ttf"),
              let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        else { return nil }
        return list.first
    }
}

// MARK: Surfaces

/// A card floating on the sky.
struct Card<Content: View>: View {
    var fill: Color = .white
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .raised(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: fill)
    }
}

/// Small label above a card's content, like "Due soon".
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.skyDeep

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(Theme.body(12, 600)).foregroundStyle(color)
        }
    }
}

/// Flat pill buttons: black for the main action, white for the rest.
struct Pill: ButtonStyle {
    enum Kind { case dark, light, accent, rec }
    var kind: Kind = .light
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, kind: kind, compact: compact)
    }

    private struct PillBody: View {
        let configuration: Configuration
        let kind: Kind
        let compact: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hover = false

        var body: some View {
            configuration.label
                .font(Theme.display(compact ? 13 : 14.5, 600))
                .labelStyle(PillLabel())
                .foregroundStyle(kind == .light ? Theme.ink : .white)
                .padding(.horizontal, compact ? 12 : 16)
                .frame(height: compact ? 30 : 36)
                .pixelBlock(hover && enabled ? fill.mix(with: .white, by: 0.08) : fill, depth: 5, pressed: configuration.isPressed)
                .scaleEffect(hover && enabled && !configuration.isPressed ? 1.03 : 1)
                .animation(.spring(duration: 0.2, bounce: 0.5), value: hover)
                .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
                .opacity(enabled ? 1 : 0.45)
                .contentShape(Rectangle())
                .onHover { hover = $0 }
        }

        private var fill: Color {
            switch kind {
            case .dark: Theme.ink
            case .light: .white
            case .accent: Theme.skyDeep
            case .rec: Theme.rec
            }
        }
    }
}

private struct PillLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            configuration.icon.font(.system(size: 11.5, weight: .bold))
            configuration.title
        }
    }
}

/// A pixel icon button. Each icon has its own little move (see GlyphMotion).
struct IconButton: View {
    var symbol: String
    var help: String
    var action: () -> Void
    @State private var hover = false
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Glyph(symbol, size: 18)
                .glyphMotion(.for(symbol), hovering: hover, taps: taps)
                .frame(width: 38, height: 36)
        }
        .buttonStyle(PixelPress(fill: hover ? Color(red: 0.94, green: 0.97, blue: 1) : .white))
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Any label as a 3D pixel block that sinks when pressed and lifts on hover.
struct PixelPress: ButtonStyle {
    var fill: Color = .white
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pixelBlock(fill, depth: depth, pressed: configuration.isPressed)
            .contentShape(Rectangle())
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: Sky

/// The 8-bit sky behind everything: dithered pixel clouds (scripts/make-sky.swift)
/// in two layers. The near layer drifts faster, which gives the sky depth.
/// Core Animation moves it on the GPU, so it glides without costing the app anything.
struct SkyBackdrop: NSViewRepresentable {
    static let far = Bundled.url("sky-far.png").flatMap(NSImage.init(contentsOf:))
    static let near = Bundled.url("sky-near.png").flatMap(NSImage.init(contentsOf:))
    /// The art is 320x200 pixels.
    static let art = CGSize(width: 320, height: 200)

    func makeNSView(context: Context) -> SkyView { SkyView() }
    func updateNSView(_ view: SkyView, context: Context) {}

    final class SkyView: NSView {
        private var builtFor: CGSize = .zero

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor(red: 0.37, green: 0.56, blue: 0.87, alpha: 1).cgColor
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            // Rebuild only when the scale changes, so resizing doesn't restart the drift.
            let k = max(2, ceil(bounds.height / SkyBackdrop.art.height))
            let size = CGSize(width: ceil(bounds.width / (SkyBackdrop.art.width * k)), height: k)
            guard size != builtFor else { return }
            builtFor = size
            layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            add(SkyBackdrop.far, k: k, secondsPerTile: 260)
            add(SkyBackdrop.near, k: k, secondsPerTile: 110)
        }

        override var isFlipped: Bool { true }

        private func add(_ image: NSImage?, k: CGFloat, secondsPerTile: Double) {
            guard let root = layer, let cg = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let tile = CGSize(width: SkyBackdrop.art.width * k, height: SkyBackdrop.art.height * k)
            let strip = CALayer()
            let count = Int(ceil(bounds.width / tile.width)) + 1
            strip.frame = CGRect(x: 0, y: 0, width: tile.width * CGFloat(count), height: tile.height)
            strip.anchorPoint = .zero
            strip.position = .zero
            for i in 0..<count {
                let l = CALayer()
                l.contents = cg
                l.magnificationFilter = .nearest
                l.frame = CGRect(x: CGFloat(i) * tile.width, y: 0, width: tile.width, height: tile.height)
                strip.addSublayer(l)
            }
            let drift = CABasicAnimation(keyPath: "position.x")
            drift.fromValue = 0
            drift.toValue = -tile.width
            drift.duration = secondsPerTile
            drift.repeatCount = .infinity
            strip.add(drift, forKey: "drift")
            root.addSublayer(strip)
        }
    }
}

/// Lifts a surface off the sky as an 8-bit block (see PixelBlock). The shape is
/// ignored: everything gets pixel corners so the whole app matches.
struct Raised<S: InsettableShape>: ViewModifier {
    var shape: S
    var fill: Color = .white
    var lift: CGFloat = 1

    func body(content: Content) -> some View {
        content.pixelBlock(fill, depth: (2 + 3 * lift).rounded())
    }
}

extension View {
    func raised<S: InsettableShape>(_ shape: S, fill: Color = .white, lift: CGFloat = 1) -> some View {
        modifier(Raised(shape: shape, fill: fill, lift: lift))
    }
}

/// Icon and title at the top of a card.
struct CardTitle: View {
    var symbol: String
    var text: String
    var color: Color = Theme.skyDeep

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(Theme.display(16, 700)).foregroundStyle(Theme.ink)
        }
    }
}

extension View {
    /// Content scrolling under the header fades out instead of being cut off.
    func scrollFade(top: CGFloat = 18, bottom: CGFloat = 18) -> some View {
        mask(VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: top)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: bottom)
        })
    }
}

/// Short Markdown (bold, bullets) in the app's own fonts. SwiftUI can't bold a
/// custom variable font from "**", so bold runs get the heavy weight directly.
struct RichText: View {
    var text: String
    var size: CGFloat = 15

    init(_ text: String, size: CGFloat = 15) {
        self.text = text
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: true).enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                let bullet = line.hasPrefix("- ") || line.hasPrefix("* ")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if bullet {
                        Rectangle().fill(Theme.sky).frame(width: 6, height: 6).offset(y: -2)
                    }
                    styled(bullet ? String(line.dropFirst(2)) : line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, bullet ? 4 : 0)
            }
        }
    }

    private func styled(_ line: String) -> Text {
        var out = Text("")
        for (i, part) in line.components(separatedBy: "**").enumerated() where !part.isEmpty {
            let bold = i % 2 == 1
            out = out + Text(part).font(Theme.body(size, bold ? 850 : 550))
                .foregroundColor(bold ? Theme.skyDeep : Theme.ink)
        }
        return out
    }
}
