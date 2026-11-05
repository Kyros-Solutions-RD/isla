//
//  IslaApp.swift
//  Isla
//
//  Isla turns the MacBook notch into a living island: music, files, calendar,
//  clipboard, focus timers and live activities, right under the camera.
//
//  Copyright © 2026 Kyros Solutions RD. MIT License.
//

import SwiftUI

@main
struct IslaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var prefs = Preferences.shared

    var body: some Scene {
        MenuBarExtra("Isla", systemImage: "capsule.portrait.inset.filled", isInserted: $prefs.showMenuBarIcon) {
            MenuBarContent()
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarContent: View {
    private let media = NowPlayingService.shared

    var body: some View {
        Button("Open Nook") { NotchManager.shared.open(.home) }
            .keyboardShortcut(" ", modifiers: [.control, .option])
        Button("Shelf") { NotchManager.shared.open(.shelf) }
        Button("Clipboard History") { NotchManager.shared.open(.clipboard) }
        Button("Focus Timer") { NotchManager.shared.open(.timers) }

        if media.hasActiveMedia, let info = media.info {
            Divider()
            Text("\(info.title) — \(info.artist)")
            Button(media.isPlaying ? "Pause" : "Play") { media.togglePlayPause() }
            Button("Next Track") { media.next() }
        }

        Divider()
        Button("Settings…") { SettingsWindowController.shared.show() }
            .keyboardShortcut(",")
        Button("About Isla") { SettingsWindowController.shared.show(pane: .about) }
        Divider()
        Button("Quit Isla") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
