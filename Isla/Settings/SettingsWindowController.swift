//
//  SettingsWindowController.swift
//  Isla
//

import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general, appearance, nook, activities, media, shelf, clipboard, calendar, focus, keyboard, permissions, about

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .nook: "Nook & Widgets"
        case .activities: "Live Activities"
        case .media: "Music"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .calendar: "Calendar & Tasks"
        case .focus: "Focus & Timers"
        case .keyboard: "Keyboard"
        case .permissions: "Privacy & Permissions"
        case .about: "About Isla"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .nook: "square.grid.2x2.fill"
        case .activities: "capsule.inset.filled"
        case .media: "music.note"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .calendar: "calendar"
        case .focus: "timer"
        case .keyboard: "keyboard.fill"
        case .permissions: "hand.raised.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .nook: .indigo
        case .activities: .purple
        case .media: .pink
        case .shelf: .teal
        case .clipboard: .orange
        case .calendar: .red
        case .focus: .orange
        case .keyboard: .gray
        case .permissions: .blue
        case .about: .gray
        }
    }

    static let groups: [[SettingsPane]] = [
        [.general, .appearance],
        [.nook, .activities],
        [.media, .shelf, .clipboard, .calendar, .focus],
        [.keyboard, .permissions],
        [.about],
    ]
}

@Observable
@MainActor
final class SettingsNavigation {
    var selection: SettingsPane? = .general
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let navigation = SettingsNavigation()

    func show(pane: SettingsPane? = nil) {
        NotchManager.shared.closeAll()
        if let pane { navigation.selection = pane }
        PermissionCenter.shared.refresh()

        if window == nil {
            let controller = NSHostingController(rootView: SettingsRootView(navigation: navigation))
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "Isla Settings")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 820, height: 600))
            window.minSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("IslaSettings")
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        // The new activation policy takes effect on the next turn of the run loop.
        DispatchQueue.main.async { [weak self] in Activation.bringToFront(self?.window) }
    }

    func windowWillClose(_ notification: Notification) {
        // Return to being a quiet menu bar app.
        DispatchQueue.main.async {
            if OnboardingWindowController.shared.isVisible == false {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
