// Composes the installer (DMG) window background from the painted artwork.
//
//   swift scripts/lib/dmg-background.swift design/dmg/artwork.png design/dmg
//
// Writes background.png (690×460) and background@2x.png (1380×920). The layout
// matches scripts/build-dmg.sh: Isla.app is centred at (178, 228) and the
// Applications link at (512, 228), in points from the top-left of the window.
import AppKit

let window = CGSize(width: 690, height: 460)
let appCenter = CGPoint(x: 178, y: 228)
let applicationsCenter = CGPoint(x: 512, y: 228)
let iconSize: CGFloat = 128

let args = CommandLine.arguments
guard args.count == 3, let art = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write("usage: dmg-background.swift <artwork.png> <output-dir>\n".data(using: .utf8)!)
    exit(1)
}
let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)

func render(scale: CGFloat) -> Data {
    let pixels = CGSize(width: window.width * scale, height: window.height * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = window  // points: AppKit draws in window coordinates, the bitmap holds `scale`× pixels
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let cg = context.cgContext

    // Flip so y grows downward, like Finder's icon positions.
    cg.translateBy(x: 0, y: window.height)
    cg.scaleBy(x: 1, y: -1)

    // 1. Artwork, aspect-fill.
    let artSize = art.size
    let fill = max(window.width / artSize.width, window.height / artSize.height)
    let drawn = CGSize(width: artSize.width * fill, height: artSize.height * fill)
    let artRect = CGRect(x: (window.width - drawn.width) / 2, y: (window.height - drawn.height) / 2,
                         width: drawn.width, height: drawn.height)
    cg.saveGState()
    cg.translateBy(x: 0, y: window.height)
    cg.scaleBy(x: 1, y: -1)
    art.draw(in: CGRect(x: artRect.minX, y: window.height - artRect.maxY, width: artRect.width, height: artRect.height))
    cg.restoreGState()

    // 2. Soft pools of light under each icon so they read as sitting on the water.
    for center in [appCenter, applicationsCenter] {
        let colors = [NSColor(white: 1, alpha: 0.16).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y + iconSize * 0.42)
        cg.scaleBy(x: 1, y: 0.22)
        cg.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: iconSize * 0.62, options: [])
        cg.restoreGState()
    }

    // 3. The arc: the sun's path from Isla to Applications.
    let start = CGPoint(x: appCenter.x + iconSize / 2 + 16, y: appCenter.y - 10)
    let end = CGPoint(x: applicationsCenter.x - iconSize / 2 - 20, y: applicationsCenter.y - 10)
    let control = CGPoint(x: (start.x + end.x) / 2, y: appCenter.y - 112)
    let arc = CGMutablePath()
    arc.move(to: start)
    arc.addQuadCurve(to: end, control: control)
    cg.saveGState()
    cg.setLineCap(.round)
    cg.setLineWidth(2.25)
    cg.setLineDash(phase: 0, lengths: [0.1, 7.5])
    cg.setShadow(offset: .zero, blur: 6, color: NSColor(calibratedRed: 1, green: 0.78, blue: 0.5, alpha: 0.55).cgColor)
    cg.setStrokeColor(NSColor(white: 1, alpha: 0.88).cgColor)
    cg.addPath(arc)
    cg.strokePath()
    cg.restoreGState()

    // Arrowhead, aligned with the curve's final tangent.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let head = CGMutablePath()
    let wing: CGFloat = 9
    head.move(to: CGPoint(x: end.x - wing * cos(angle - .pi / 5), y: end.y - wing * sin(angle - .pi / 5)))
    head.addLine(to: end)
    head.addLine(to: CGPoint(x: end.x - wing * cos(angle + .pi / 5), y: end.y - wing * sin(angle + .pi / 5)))
    cg.saveGState()
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    cg.setLineWidth(2.25)
    cg.setShadow(offset: .zero, blur: 6, color: NSColor(calibratedRed: 1, green: 0.78, blue: 0.5, alpha: 0.55).cgColor)
    cg.setStrokeColor(NSColor(white: 1, alpha: 0.92).cgColor)
    cg.addPath(head)
    cg.strokePath()
    cg.restoreGState()

    // 4. Type.
    func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat, tracking: CGFloat = 0) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.1, alpha: 0.45)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(white: 1, alpha: alpha),
            .paragraphStyle: paragraph,
            .kern: tracking,
            .shadow: shadow,
        ]
        let line = NSAttributedString(string: string, attributes: attributes)
        let height = line.size().height
        // Draw in an unflipped space so glyphs are upright.
        cg.saveGState()
        cg.translateBy(x: 0, y: window.height)
        cg.scaleBy(x: 1, y: -1)
        line.draw(in: CGRect(x: 0, y: window.height - y - height / 2, width: window.width, height: height))
        cg.restoreGState()
    }
    text("Arrastra Isla a Aplicaciones", size: 25, weight: .semibold, alpha: 1, y: 56, tracking: -0.3)
    text("Drag Isla to Applications", size: 13, weight: .regular, alpha: 0.72, y: 86)
    text("¿macOS no la abre la primera vez? Ajustes del Sistema › Privacidad y seguridad › Abrir igualmente",
         size: 10.5, weight: .regular, alpha: 0.66, y: 404)
    text("Blocked on first launch? System Settings › Privacy & Security › Open Anyway",
         size: 10.5, weight: .regular, alpha: 0.5, y: 421)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try render(scale: 1).write(to: outputDir.appendingPathComponent("background.png"))
try render(scale: 2).write(to: outputDir.appendingPathComponent("background@2x.png"))
print("✓ \(outputDir.path)/background.png and background@2x.png")
