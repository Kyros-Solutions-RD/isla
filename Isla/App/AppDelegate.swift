//
//  AppDelegate.swift
//  Isla
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var deferredServicesStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Services that need no permission start right away.
        BatteryMonitor.shared.start()
        SystemAudio.shared.start()
        CapsLockMonitor.shared.start()
        NowPlayingService.shared.start()
        ClipboardStore.shared.start()
        NotchManager.shared.start()
        Self.registerHotKeys()

        if Preferences.shared.hasCompletedOnboarding {
            Self.startDeferredServices()
        } else {
            OnboardingWindowController.shared.show()
        }
    }

    /// Services that may show a permission prompt wait until after onboarding.
    static func startDeferredServices() {
        guard !deferredServicesStarted else { return }
        deferredServicesStarted = true
        CalendarService.shared.start()
        TasksStore.shared.start()
        WeatherService.shared.start()
        BluetoothMonitor.shared.start()
        MediaKeyTap.shared.update()
        UpdateChecker.shared.start()
        if Preferences.shared.activityDownloads {
            DownloadsWatcher.shared.start()
        }
    }

    static func registerHotKeys() {
        let prefs = Preferences.shared
        HotKeyCenter.shared.register(.toggleNotch, combo: prefs.toggleHotKey) { NotchManager.shared.toggle() }
        HotKeyCenter.shared.register(.clipboard, combo: prefs.clipboardHotKey) { NotchManager.shared.toggle(.clipboard) }
        HotKeyCenter.shared.register(.shelf, combo: prefs.shelfHotKey) { NotchManager.shared.toggle(.shelf) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // isla://open/<tab>, isla://settings
        for url in urls where url.scheme == "isla" {
            if url.host() == "settings" {
                SettingsWindowController.shared.show()
            } else if url.host() == "close" {
                NotchManager.shared.closeAll()
            } else if url.host() == "demo" {
                #if DEBUG
                DemoActivities.run(url.pathComponents.dropFirst().first ?? "")
                #endif
            } else {
                let tab = url.pathComponents.dropFirst().first.flatMap(NotchTab.init(rawValue:))
                let wantsMain = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.contains { $0.name == "screen" && $0.value == "main" } ?? false
                if wantsMain, let main = NSScreen.screens.first,
                   let controller = NotchManager.shared.controllers[main.displayID] {
                    controller.open(tab, makeKey: true)
                } else {
                    NotchManager.shared.open(tab)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingService.shared.stop()
        QuickActions.shared.stopKeepAwake()
    }
}
