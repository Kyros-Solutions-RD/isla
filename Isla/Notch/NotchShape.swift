//
//  NotchShape.swift
//  Isla
//
//  The silhouette of the notch: a flat top that flows out of the screen edge
//  through two concave "shoulders", straight sides and soft bottom corners.
//

import SwiftUI

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    init(topRadius: CGFloat = 6, bottomRadius: CGFloat = 12) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.width / 4, rect.height / 2)
        let bottom = min(bottomRadius, (rect.width - top * 2) / 2, rect.height - top)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Left shoulder curving inward from the screen edge.
        path.addCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                      control1: CGPoint(x: rect.minX + top * 0.62, y: rect.minY),
                      control2: CGPoint(x: rect.minX + top, y: rect.minY + top * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))

        // Bottom-left corner (continuous-style curve).
        path.addCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                      control1: CGPoint(x: rect.minX + top, y: rect.maxY - bottom * 0.45),
                      control2: CGPoint(x: rect.minX + top + bottom * 0.45, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))

        // Bottom-right corner.
        path.addCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                      control1: CGPoint(x: rect.maxX - top - bottom * 0.45, y: rect.maxY),
                      control2: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))

        // Right shoulder back to the screen edge.
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                      control1: CGPoint(x: rect.maxX - top, y: rect.minY + top * 0.38),
                      control2: CGPoint(x: rect.maxX - top * 0.62, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
