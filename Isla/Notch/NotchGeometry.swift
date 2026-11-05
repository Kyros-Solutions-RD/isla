//
//  NotchGeometry.swift
//  Isla
//
//  Measures the camera housing on notched displays and synthesizes a matching
//  virtual notch on every other screen.
//

import AppKit

struct NotchGeometry: Equatable {
    /// Screen frame in global AppKit coordinates (origin bottom-left).
    let screenFrame: CGRect
    /// Whether the display has a physical camera housing.
    let hasHardwareNotch: Bool
    /// Size of the camera housing (or the virtual notch).
    let notchSize: CGSize
    /// Horizontal center of the notch in global coordinates.
    let centerX: CGFloat

    var topY: CGFloat { screenFrame.maxY }

    static func make(for screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = max(120, frame.width - left.width - right.width)
            let centerX = frame.minX + left.width + width / 2
            return NotchGeometry(screenFrame: frame,
                                 hasHardwareNotch: true,
                                 notchSize: CGSize(width: width, height: topInset),
                                 centerX: centerX)
        }

        let menuBar = frame.maxY - screen.visibleFrame.maxY
        let height = min(max(menuBar > 0 ? menuBar : 24, 22), 32)
        return NotchGeometry(screenFrame: frame,
                             hasHardwareNotch: false,
                             notchSize: CGSize(width: 184, height: height),
                             centerX: frame.midX)
    }

    /// Rect of a top-anchored, horizontally centered shape of `size`.
    func rect(for size: CGSize) -> CGRect {
        CGRect(x: centerX - size.width / 2, y: topY - size.height, width: size.width, height: size.height)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var hasHardwareNotch: Bool { safeAreaInsets.top > 0 }
}
