//
//  IslaGlyph.swift
//  Isla
//
//  The Isla mark — the notch as an island with the sun inside — drawn as a
//  vector template image for the menu bar.
//

import AppKit

enum IslaGlyph {
    /// The mark path in a 64 × 40 design space (y grows downward).
    static func path(in rect: CGRect) -> NSBezierPath {
        let sx = rect.width / 64, sy = rect.height / 40
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * sx, y: rect.maxY - y * sy) }

        let shape = NSBezierPath()
        shape.move(to: p(0, 0))
        shape.line(to: p(64, 0))
        shape.curve(to: p(53, 9), controlPoint1: p(57.5, 0), controlPoint2: p(53, 2.5))
        shape.line(to: p(53, 23))
        shape.curve(to: p(37, 39), controlPoint1: p(53, 32), controlPoint2: p(46, 39))
        shape.line(to: p(27, 39))
        shape.curve(to: p(11, 23), controlPoint1: p(18, 39), controlPoint2: p(11, 32))
        shape.line(to: p(11, 9))
        shape.curve(to: p(0, 0), controlPoint1: p(11, 2.5), controlPoint2: p(6.5, 0))
        shape.close()

        let sunRadius = 7.5 * min(sx, sy)
        let center = p(32, 21)
        shape.appendOval(in: NSRect(x: center.x - sunRadius, y: center.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
        shape.windingRule = .evenOdd
        return shape
    }

    /// Menu bar template image.
    static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 14), flipped: false) { rect in
            NSColor.black.setFill()
            path(in: rect.insetBy(dx: 0, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Isla"
        return image
    }()
}
