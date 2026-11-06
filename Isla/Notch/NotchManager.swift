//
//  NotchManager.swift
//  Isla
//
//  Creates one notch per display according to the user's placement choice and
//  keeps them in sync with screen and Space changes.
//

import AppKit

@MainActor
final class NotchManager {
    static let shared = NotchManager()

    private(set) var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        rebuild()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { NotchManager.shared.rebuild() }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    // Full-screen transitions settle a moment after the notification.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        NotchManager.shared.updateFullScreenVisibility()
                    }
                }
            })
        }
    }

    func rebuild() {
        let placement = Preferences.shared.displayPlacement
        let screens: [NSScreen] = NSScreen.screens.filter { screen in
            switch placement {
            case .allDisplays: return true
            case .mainDisplay: return screen == NSScreen.screens.first
            case .notchedDisplays: return screen.hasHardwareNotch
            }
        }
        // Fall back to the main display so Isla is never invisible.
        let targets = screens.isEmpty ? Array(NSScreen.screens.prefix(1)) : screens
        let ids = Set(targets.map(\.displayID))

        for (id, controller) in controllers where !ids.contains(id) {
            controller.setHidden(true)
            controllers.removeValue(forKey: id)
        }
        for screen in targets {
            if let existing = controllers[screen.displayID] {
                existing.update(screen: screen)
            } else {
                controllers[screen.displayID] = NotchWindowController(screen: screen)
            }
        }
        updateFullScreenVisibility()
    }

    /// The notch on the display under the pointer, or the main one.
    var activeController: NotchWindowController? {
        let location = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }),
           let controller = controllers[screen.displayID] {
            return controller
        }
        if let main = NSScreen.main, let controller = controllers[main.displayID] { return controller }
        return controllers.values.first
    }

    func toggle(_ tab: NotchTab? = nil) {
        activeController?.toggle(tab)
    }

    func open(_ tab: NotchTab? = nil) {
        activeController?.open(tab, makeKey: true)
    }

    /// Whether a notch is on screen somewhere (closed or open, both show what arrives).
    var isNotchVisible: Bool {
        controllers.values.contains { $0.panel.isVisible }
    }

    func closeAll() {
        controllers.values.forEach { $0.close() }
    }

    func updateFullScreenVisibility() {
        let hide = Preferences.shared.hideInFullScreen
        let fullScreenDisplays = hide ? FullScreenDetector.displaysWithFullScreenApp() : []
        for (id, controller) in controllers {
            controller.setHidden(fullScreenDisplays.contains(id))
        }
    }
}

enum FullScreenDetector {
    /// Displays whose frontmost window covers the entire screen, menu bar included.
    @MainActor
    static func displaysWithFullScreenApp() -> Set<CGDirectDisplayID> {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result = Set<CGDirectDisplayID>()
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return [] }

        for window in info {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let owner = window[kCGWindowOwnerName as String] as? String, owner != "Finder" else { continue }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            for screen in screens {
                // Convert AppKit (bottom-left) to Quartz (top-left) coordinates.
                let frame = screen.frame
                let quartz = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
                if abs(rect.minX - quartz.minX) < 1, abs(rect.minY - quartz.minY) < 1,
                   abs(rect.width - quartz.width) < 1, abs(rect.height - quartz.height) < 1 {
                    result.insert(screen.displayID)
                }
            }
        }
        return result
    }
}
