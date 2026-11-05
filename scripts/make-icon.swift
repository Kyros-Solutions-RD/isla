#!/usr/bin/env swift
//
//  make-icon.swift
//  Renders Isla's app icon at every size macOS needs.
//
//  Usage: swift scripts/make-icon.swift <output .appiconset directory>
//

import AppKit
import CoreGraphics

let outputDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Isla/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Continuous-corner squircle similar to the macOS icon mask.
func squircle(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let r = rect.width * 0.225
    let k: CGFloat = 0.552 * 1.28
    let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
    path.move(to: CGPoint(x: minX + r, y: minY))
    path.addLine(to: CGPoint(x: maxX - r, y: minY))
    path.addCurve(to: CGPoint(x: maxX, y: minY + r), control1: CGPoint(x: maxX - r + r * k, y: minY), control2: CGPoint(x: maxX, y: minY + r - r * k))
    path.addLine(to: CGPoint(x: maxX, y: maxY - r))
    path.addCurve(to: CGPoint(x: maxX - r, y: maxY), control1: CGPoint(x: maxX, y: maxY - r + r * k), control2: CGPoint(x: maxX - r + r * k, y: maxY))
    path.addLine(to: CGPoint(x: minX + r, y: maxY))
    path.addCurve(to: CGPoint(x: minX, y: maxY - r), control1: CGPoint(x: minX + r - r * k, y: maxY), control2: CGPoint(x: minX, y: maxY - r + r * k))
    path.addLine(to: CGPoint(x: minX, y: minY + r))
    path.addCurve(to: CGPoint(x: minX + r, y: minY), control1: CGPoint(x: minX, y: minY + r - r * k), control2: CGPoint(x: minX + r - r * k, y: minY))
    path.closeSubpath()
    return path
}

/// The island silhouette (top-anchored notch) in a flipped coordinate space.
func islandPath(center: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, shoulder: CGFloat, bottom: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = center - width / 2, maxX = center + width / 2
    // Coordinates here are y-down; caller flips the context.
    path.move(to: CGPoint(x: minX - shoulder, y: top))
    path.addCurve(to: CGPoint(x: minX, y: top + shoulder), control1: CGPoint(x: minX - shoulder * 0.38, y: top), control2: CGPoint(x: minX, y: top + shoulder * 0.38))
    path.addLine(to: CGPoint(x: minX, y: top + height - bottom))
    path.addCurve(to: CGPoint(x: minX + bottom, y: top + height), control1: CGPoint(x: minX, y: top + height - bottom * 0.45), control2: CGPoint(x: minX + bottom * 0.45, y: top + height))
    path.addLine(to: CGPoint(x: maxX - bottom, y: top + height))
    path.addCurve(to: CGPoint(x: maxX, y: top + height - bottom), control1: CGPoint(x: maxX - bottom * 0.45, y: top + height), control2: CGPoint(x: maxX, y: top + height - bottom * 0.45))
    path.addLine(to: CGPoint(x: maxX, y: top + shoulder))
    path.addCurve(to: CGPoint(x: maxX + shoulder, y: top), control1: CGPoint(x: maxX, y: top + shoulder * 0.38), control2: CGPoint(x: maxX + shoulder * 0.38, y: top))
    path.closeSubpath()
    return path
}

func render(size: Int) -> Data? {
    let s = CGFloat(size)
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // Work in a y-down space sized 1024 for easy reasoning.
    context.translateBy(x: 0, y: s)
    context.scaleBy(x: s / 1024, y: -s / 1024)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let mask = squircle(in: body)

    // Drop shadow under the tile.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: color(0, 0, 0, 0.35))
    context.addPath(mask)
    context.setFillColor(color(20, 24, 60))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(mask)
    context.clip()

    // Caribbean dusk: deep indigo sky melting into coral at the horizon.
    let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                         colors: [color(14, 18, 52), color(46, 38, 120), color(150, 62, 150), color(246, 112, 104), color(255, 176, 112)] as CFArray,
                         locations: [0, 0.32, 0.6, 0.84, 1])!
    context.drawLinearGradient(sky, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

    // Soft aurora glows.
    func glow(_ center: CGPoint, _ radius: CGFloat, _ c: CGColor) {
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c, c.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    glow(CGPoint(x: 250, y: 330), 380, color(64, 196, 255, 0.45))
    glow(CGPoint(x: 820, y: 420), 340, color(255, 84, 196, 0.38))
    glow(CGPoint(x: 512, y: 980), 420, color(255, 214, 150, 0.6))

    // Setting sun, clipped at the horizon.
    let seaTop: CGFloat = 760
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: 0, width: 1024, height: seaTop))
    glow(CGPoint(x: 512, y: seaTop), 260, color(255, 200, 140, 0.55))
    let sun = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                         colors: [color(255, 246, 214), color(255, 196, 128)] as CFArray, locations: [0, 1])!
    context.addEllipse(in: CGRect(x: 512 - 118, y: seaTop - 118, width: 236, height: 236))
    context.clip()
    context.drawLinearGradient(sun, start: CGPoint(x: 512, y: seaTop - 118), end: CGPoint(x: 512, y: seaTop), options: [])
    context.restoreGState()

    // Sea: a calm reflective band at the bottom.
    let sea = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                         colors: [color(120, 60, 120, 0.95), color(46, 40, 112, 0.97), color(18, 20, 60, 1)] as CFArray,
                         locations: [0, 0.4, 1])!
    context.drawLinearGradient(sea, start: CGPoint(x: 512, y: seaTop), end: CGPoint(x: 512, y: 924), options: [])
    // Sun reflection streaks.
    for (index, width) in [236.0, 184.0, 132.0, 86.0, 48.0].enumerated() {
        let y = seaTop + 18 + CGFloat(index) * 30
        let rect = CGRect(x: 512 - width / 2, y: y, width: width, height: 9)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 4.5, cornerHeight: 4.5, transform: nil))
        context.setFillColor(color(255, 214, 160, 0.7 - CGFloat(index) * 0.1))
        context.fillPath()
    }

    // The island: a black notch hanging from the top edge, like the real one.
    let island = islandPath(center: 512, top: 100, width: 470, height: 196, shoulder: 34, bottom: 82)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 22), blur: 46, color: color(0, 0, 20, 0.55))
    context.addPath(island)
    context.setFillColor(color(4, 4, 8))
    context.fillPath()
    context.restoreGState()

    // Glass sheen on the island's lower edge.
    context.saveGState()
    context.addPath(island)
    context.clip()
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [color(255, 255, 255, 0.0), color(255, 255, 255, 0.0), color(255, 255, 255, 0.16)] as CFArray,
                           locations: [0, 0.6, 1])!
    context.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 296), options: [])
    context.restoreGState()

    // Live activity inside the island: album art on the left, equalizer on the right.
    let art = CGRect(x: 318, y: 178, width: 86, height: 86)
    let artPath = CGPath(roundedRect: art, cornerWidth: 22, cornerHeight: 22, transform: nil)
    context.saveGState()
    context.addPath(artPath)
    context.clip()
    let artGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [color(255, 120, 90), color(255, 64, 160), color(120, 80, 255)] as CFArray,
                                 locations: [0, 0.55, 1])!
    context.drawLinearGradient(artGradient, start: CGPoint(x: art.minX, y: art.minY), end: CGPoint(x: art.maxX, y: art.maxY), options: [])
    context.restoreGState()

    let bars: [CGFloat] = [40, 78, 58, 88]
    for (index, height) in bars.enumerated() {
        let x = 610 + CGFloat(index) * 24
        let rect = CGRect(x: x, y: 221 - height / 2, width: 13, height: height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil))
    }
    context.setFillColor(color(255, 140, 190))
    context.fillPath()

    // Camera lens hint.
    context.setFillColor(color(28, 30, 48))
    context.fillEllipse(in: CGRect(x: 497, y: 128, width: 30, height: 30))
    context.setFillColor(color(60, 80, 140, 0.8))
    context.fillEllipse(in: CGRect(x: 506, y: 137, width: 12, height: 12))

    context.restoreGState()

    // Liquid Glass rim: a fine highlight around the tile.
    context.saveGState()
    context.addPath(mask)
    context.setLineWidth(5)
    context.setStrokeColor(color(255, 255, 255, 0.22))
    context.strokePath()
    context.restoreGState()

    guard let image = context.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

let sizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for entry in sizes {
    let pixels = entry.points * entry.scale
    let name = "icon_\(entry.points)x\(entry.points)\(entry.scale == 2 ? "@2x" : "").png"
    if let data = render(size: pixels) {
        try? data.write(to: outputDirectory.appendingPathComponent(name))
    }
    images.append(["idiom": "mac", "size": "\(entry.points)x\(entry.points)", "scale": "\(entry.scale)x", "filename": name])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))

// A large render for the website and README.
if CommandLine.arguments.count > 2, let data = render(size: 1024) {
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
print("Icon written to \(outputDirectory.path)")
