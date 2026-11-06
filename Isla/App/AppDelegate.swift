//
//  AppDelegate.swift
//  Isla
//

import AppKit
import CoreLocation
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
        AgentMonitor.shared.start()
        NotchManager.shared.start()
        // Reads banners through Accessibility only if it is already allowed: never prompts.
        NotificationMirror.shared.refresh()
        Self.registerHotKeys()

        // Permission report: prints which grants this build has, without asking for any.
        // Used to confirm that updates keep their permissions.
        if ProcessInfo.processInfo.environment["ISLA_PERMISSION_REPORT"] == "1" {
            // Location's answer arrives a moment after the first location manager exists, and
            // sometimes well after 1.5 s: wait for it (up to about 6 s) instead of guessing.
            let locationProbe = CLLocationManager()
            func finish(attempt: Int) {
                if locationProbe.authorizationStatus == .notDetermined && attempt < 24 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { finish(attempt: attempt + 1) }
                    return
                }
                PermissionCenter.shared.refresh()
                let report = PermissionKind.allCases.map { "\($0.rawValue)=\(PermissionCenter.shared.isGranted($0) ? "granted" : "missing")" }
                print("isla-permissions " + report.joined(separator: " "))
                print("isla-permissions-raw " + PermissionCenter.rawStatuses())
                exit(0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { finish(attempt: 0) }
            return
        }

        #if DEBUG
        // Agents report: prints the agents, apps and local models Isla detects, then quits.
        if ProcessInfo.processInfo.environment["ISLA_AGENTS_REPORT"] == "1" {
            Task {
                await AgentMonitor.shared.report()
                exit(0)
            }
            return
        }
        #endif

        // Launch check run by scripts/build-dmg.sh: it exercises the launch path that needs
        // no permission (frameworks, notch, media helper, welcome window and its activation),
        // then reports. Nothing is saved and no permission prompt is triggered.
        if ProcessInfo.processInfo.environment["ISLA_LAUNCH_CHECK"] == "1" {
            OnboardingWindowController.shared.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("isla-launch-check-ok")
                exit(0)
            }
            return
        }

        #if DEBUG
        // Test mode for Debug builds (`--env ISLA_TEST=1`): the notch and the services that need
        // no permission run, but no welcome tour and nothing that could show a permission prompt.
        if ProcessInfo.processInfo.environment["ISLA_TEST"] == "1" { return }
        #endif

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
        UpdateManager.shared.start()
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
        // isla://open/<tab>, isla://settings[/<pane>] (isla-dev:// in Debug builds)
        for url in urls where url.scheme == "isla" || url.scheme == "isla-dev" {
            if url.host() == "settings" {
                let pane = url.pathComponents.dropFirst().first.flatMap(SettingsPane.init(rawValue:))
                SettingsWindowController.shared.show(pane: pane)
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
