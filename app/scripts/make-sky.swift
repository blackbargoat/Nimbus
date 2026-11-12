// Draws the 8-bit pixel sky used by the app and the website: dithered clouds on
// flat blue, tileable left to right so it can scroll forever.
//   swift scripts/make-sky.swift <out-folder>
// Writes sky-far.png (opaque blue with faint clouds) and sky-near.png (bright
// clouds on transparent), each 320x200 pixels. Show them scaled up with no smoothing.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let W = 320, H = 200

struct RGBA { var r, g, b, a: UInt8 }
let sky = RGBA(r: 0x5E, g: 0x8F, b: 0xDE, a: 255)
let skyLow = RGBA(r: 0x7C, g: 0xA6, b: 0xE8, a: 255)

// Value noise that wraps every `period` cells horizontally.
func hash(_ x: Int, _ y: Int, _ seed: Int) -> Double {
    var h = UInt64(bitPattern: Int64(x &* 374761393 &+ y &* 668265263 &+ seed &* 2147483647))
    h = (h ^ (h >> 13)) &* 1274126177
    h ^= h >> 16
    return Double(h & 0xFFFF) / 65535
}

func noise(_ x: Double, _ y: Double, period: Int, seed: Int) -> Double {
    let x0 = Int(floor(x)), y0 = Int(floor(y))
    let fx = x - Double(x0), fy = y - Double(y0)
    let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
    func v(_ i: Int, _ j: Int) -> Double { hash(((i % period) + period) % period, j, seed) }
    let a = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * sx
    let b = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * sx
    return a + (b - a) * sy
}

func fbm(_ x: Double, _ y: Double, seed: Int) -> Double {
    var total = 0.0, amp = 0.5, freq = 1.0, norm = 0.0
    for octave in 0..<5 {
        let period = 8 << octave
        total += amp * noise(x * freq * 8, y * freq * 8, period: period, seed: seed + octave * 31)
        norm += amp
        amp *= 0.5
        freq *= 2
    }
    return total / norm
}

let bayer: [[Double]] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]].map { $0.map { ($0 + 0.5) / 16 } }

struct Cloud { var x, y, w, h: Double }

/// A puffy cloud: a cluster of round puffs over a flatter base, edges roughened by noise.
/// Distances wrap left to right so the image tiles.
func density(_ px: Int, _ py: Int, seed: Int, clouds: [Cloud]) -> Double {
    var best = -10.0
    let edge = fbm(Double(px) / Double(W), Double(py) / Double(H), seed: seed) - 0.5
    for (i, c) in clouds.enumerated() {
        var dx = Double(px) - c.x
        dx -= Double(W) * (dx / Double(W)).rounded()
        let dy = Double(py) - c.y
        // Puffs along the top, seeded per cloud.
        var d = -10.0
        let puffs = 5
        for k in 0..<puffs {
            let t = Double(k) / Double(puffs - 1) - 0.5
            let r = c.h * (0.55 + 0.45 * hash(i, k, seed) ) * (1 - abs(t) * 0.7)
            let ox = t * c.w * 0.8, oy = -r * 0.35
            let dist = hypot(dx - ox, (dy - oy) * 1.15) / r
            d = max(d, 1 - dist)
        }
        // Flat-ish base.
        let base = 1 - max(abs(dx) / (c.w * 0.55), abs(dy - c.h * 0.15) / (c.h * 0.45))
        d = max(d, base)
        best = max(best, d)
    }
    // Rough edges only near a cloud, so open sky stays flat blue.
    let near = max(0, min(1, (best + 0.25) * 2))
    return max(0, min(1, (best + edge * 0.45 * near) * 2.2))
}

func render(_ name: String, to folder: URL, transparent: Bool, seed: Int, clouds: [Cloud],
            ramp: [RGBA]) throws {
    var pixels = [UInt8](repeating: 0, count: W * H * 4)
    for y in 0..<H {
        for x in 0..<W {
            let d = density(x, y, seed: seed, clouds: clouds)
            // Pick between two neighbouring colours on the ramp with ordered dithering.
            let pos = d * Double(ramp.count - 1)
            let lo = Int(pos), frac = pos - Double(lo)
            let idx = min(ramp.count - 1, frac > bayer[y % 4][x % 4] ? lo + 1 : lo)
            var c = ramp[idx]
            if !transparent && idx == 0 {
                // Base sky gets slightly lighter toward the bottom, in dithered steps.
                c = Double(y) / Double(H) > 0.82 && (Double(y) / Double(H) - 0.82) * 5 > bayer[y % 4][(x + 2) % 4] ? skyLow : sky
            }
            let o = (y * W + x) * 4
            // Premultiplied alpha for CoreGraphics.
            let a = Double(c.a) / 255
            pixels[o] = UInt8(Double(c.r) * a); pixels[o + 1] = UInt8(Double(c.g) * a)
            pixels[o + 2] = UInt8(Double(c.b) * a); pixels[o + 3] = c.a
        }
    }
    let ctx = CGContext(data: &pixels, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let url = folder.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    print("wrote", url.path)
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let clear = RGBA(r: 0, g: 0, b: 0, a: 0)
try render("sky-far.png", to: out, transparent: false, seed: 7,
           clouds: [Cloud(x: 40, y: 30, w: 70, h: 16), Cloud(x: 190, y: 62, w: 56, h: 13), Cloud(x: 270, y: 150, w: 80, h: 18), Cloud(x: 110, y: 120, w: 44, h: 11), Cloud(x: 300, y: 18, w: 40, h: 10)],
           ramp: [sky, RGBA(r: 0x8C, g: 0xB2, b: 0xEC, a: 255), RGBA(r: 0xB9, g: 0xD1, b: 0xF5, a: 255)])
try render("sky-near.png", to: out, transparent: true, seed: 101,
           clouds: [Cloud(x: 90, y: 72, w: 96, h: 24), Cloud(x: 250, y: 120, w: 110, h: 26), Cloud(x: 30, y: 178, w: 70, h: 18), Cloud(x: 200, y: 22, w: 50, h: 13)],
           ramp: [clear, RGBA(r: 0xA8, g: 0xC7, b: 0xF3, a: 255), RGBA(r: 0xD6, g: 0xE6, b: 0xFA, a: 255),
                  RGBA(r: 0xFF, g: 0xFF, b: 0xFF, a: 255)])
