// Draws the Nimbus app icon (white cloud on a sky gradient) into an .iconset.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.09
    let tile = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.96, green: 0.98, blue: 1, alpha: 1),
                        NSColor(red: 0.62, green: 0.80, blue: 0.99, alpha: 1),
                        NSColor(red: 0.30, green: 0.58, blue: 0.95, alpha: 1)])!
        .draw(in: shape, angle: 90)

    // Cloud, in the icon's own coordinates (y up).
    let w = tile.width, ox = tile.minX, oy = tile.minY
    // Same puffs as CloudShape, fitted into a box centered in the tile.
    let cw = w * 0.78, ch = cw * 0.72
    let cx0 = ox + (w - cw) / 2, cy0 = oy + (w - ch) / 2 + w * 0.02
    let cloud = NSBezierPath()
    for (px, py, r) in [(0.18, 0.66, 0.14), (0.36, 0.46, 0.19), (0.58, 0.36, 0.23), (0.78, 0.52, 0.17), (0.88, 0.70, 0.11),
                        (0.30, 0.86, 0.09), (0.55, 0.88, 0.10), (0.76, 0.86, 0.085)] as [(CGFloat, CGFloat, CGFloat)] {
        let x = cx0 + px * cw, y = cy0 + (1 - py) * ch
        cloud.append(NSBezierPath(ovalIn: NSRect(x: x - r * cw, y: y - r * cw, width: 2 * r * cw, height: 2 * r * cw)))
    }
    cloud.append(NSBezierPath(roundedRect: NSRect(x: cx0 + 0.06 * cw, y: cy0 + (1 - 0.92) * ch, width: 0.88 * cw, height: 0.37 * ch),
                              xRadius: 0.18 * ch, yRadius: 0.18 * ch))
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
    shadow.shadowBlurRadius = s * 0.04
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    cloud.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Face
    let ink = NSColor(red: 0.07, green: 0.13, blue: 0.24, alpha: 1)
    ink.setFill()
    for ex in [0.45, 0.61] {
        NSBezierPath(roundedRect: NSRect(x: ox + (ex - 0.022) * w, y: oy + 0.44 * w, width: 0.044 * w, height: 0.075 * w),
                     xRadius: 0.022 * w, yRadius: 0.022 * w).fill()
    }
    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: ox + 0.48 * w, y: oy + 0.395 * w))
    mouth.curve(to: NSPoint(x: ox + 0.58 * w, y: oy + 0.395 * w),
                controlPoint1: NSPoint(x: ox + 0.505 * w, y: oy + 0.36 * w),
                controlPoint2: NSPoint(x: ox + 0.555 * w, y: oy + 0.36 * w))
    mouth.lineWidth = 0.02 * w
    mouth.lineCapStyle = .round
    ink.setStroke()
    mouth.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! draw(px).write(to: out.appendingPathComponent("icon_\(name).png"))
}
