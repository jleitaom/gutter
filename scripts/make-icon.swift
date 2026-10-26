#!/usr/bin/env swift
// Renders the Gutter app icon ("Glass": a frosted window beside a Stage Manager tile).
// Usage: swift scripts/make-icon.swift  → writes Resources/AppIcon.icns and docs/icon.png
import AppKit

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: nil)!
}

/// Fills `path` with a linear gradient running from its top-left to its bottom-right corner.
func fillDiagonal(_ ctx: CGContext, _ path: CGPath, _ colors: [CGColor]) {
    let box = path.boundingBox
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient(colors), start: CGPoint(x: box.minX, y: box.minY), end: CGPoint(x: box.maxX, y: box.maxY), options: [])
    ctx.restoreGState()
}

/// Draws the icon on a 1024×1024 canvas with a top-left origin, scaled to `size`.
func drawIcon(in ctx: CGContext, size: CGFloat) {
    let scale = size / 1024
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)

    // Body (macOS icon grid: 824pt squircle centered in 1024)
    let body = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 32 * scale, color: color(0, 0, 0, 0.28))
    ctx.addPath(body)
    ctx.setFillColor(color(214, 222, 234))
    ctx.fillPath()
    ctx.restoreGState()
    fillDiagonal(ctx, body, [color(241, 244, 249), color(197, 207, 222)])

    // Stage Manager tile, partly behind the window
    let tile = roundedRect(CGRect(x: 186, y: 340, width: 190, height: 344), 44)
    ctx.addPath(tile)
    ctx.setFillColor(color(255, 255, 255, 0.5))
    ctx.fillPath()
    ctx.addPath(tile)
    ctx.setStrokeColor(color(255, 255, 255))
    ctx.setLineWidth(4)
    ctx.strokePath()

    // Frosted glass window
    let window = roundedRect(CGRect(x: 334, y: 214, width: 480, height: 596), 64)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -22 * scale), blur: 60 * scale, color: color(61, 75, 102, 0.28))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    fillDiagonal(ctx, window, [color(255, 255, 255, 0.95), color(255, 255, 255, 0.55)])
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    ctx.addPath(window)
    ctx.setStrokeColor(color(255, 255, 255))
    ctx.setLineWidth(5)
    ctx.strokePath()

    // Two content lines
    for (rect, alpha) in [(CGRect(x: 384, y: 268, width: 160, height: 22), 0.35), (CGRect(x: 384, y: 318, width: 250, height: 22), 0.2)] {
        ctx.addPath(roundedRect(rect, 11))
        ctx.setFillColor(color(111, 134, 176, alpha))
        ctx.fillPath()
    }
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    drawIcon(in: context.cgContext, size: CGFloat(pixels))
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try png(pixels: 512).write(to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns and docs/icon.png" : "iconutil failed")
