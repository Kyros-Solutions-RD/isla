//
//  UpdateManager.swift
//  Isla
//
//  Automatic updates through Sparkle. Isla checks its appcast once a day;
//  when a new version is ready the island lets you know, and one click opens
//  the native update window.
//

import AppKit
import Sparkle

@Observable
@MainActor
final class UpdateManager: NSObject {
    static let shared = UpdateManager()

    /// Version found by a background check that the user has not seen yet.
    private(set) var availableVersion: String?

    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    private override init() { super.init() }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var updater: SPUUpdater? { controller?.updater }

    var automaticallyChecks: Bool {
        get { updater?.automaticallyChecksForUpdates ?? true }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloads: Bool {
        get { updater?.automaticallyDownloadsUpdates ?? false }
        set { updater?.automaticallyDownloadsUpdates = newValue }
    }

    var lastChecked: Date? { updater?.lastUpdateCheckDate }

    func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        automaticallyChecks = Preferences.shared.checkForUpdates
    }

    /// Opens Sparkle's native "Check for Updates" window.
    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}

// MARK: - Sparkle delegates

extension UpdateManager: SPUUpdaterDelegate {}

extension UpdateManager: SPUStandardUserDriverDelegate {
    /// Isla lives in the menu bar, so scheduled updates are announced gently on the island.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            guard !handleShowingUpdate, !state.userInitiated else { return }
            self.availableVersion = version
            LiveActivityCenter.shared.post(.message(symbol: "arrow.down.app.fill",
                                                    title: String(localized: "Isla \(version) is available")), duration: 5)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { self.availableVersion = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { self.availableVersion = nil }
    }
}
