//
//  Activation.swift
//  Isla
//

import AppKit

/// Brings Isla to the front before it shows a window or a system panel.
///
/// Isla is a menu bar app (LSUIElement). On macOS 14 and later the cooperative
/// `NSApp.activate()` is ignored for such an app when it opens a window on its own,
/// at launch or from the notch panel (which never activates the app). The window then
/// appears in front but not key: grey buttons and no keyboard until it is clicked.
/// When the cooperative request is not granted, Isla falls back to the classic call.
@MainActor
enum Activation {
    static func bringToFront(_ window: NSWindow? = nil) {
        NSApp.activate()
        if !NSApp.isActive, NSApp.responds(to: #selector(LegacyActivation.activate(ignoringOtherApps:))) {
            unsafeBitCast(NSApp!, to: LegacyActivation.self).activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

/// `-[NSApplication activateIgnoringOtherApps:]`, reached without its deprecation warning.
@objc private protocol LegacyActivation {
    @objc(activateIgnoringOtherApps:) func activate(ignoringOtherApps flag: Bool)
}
