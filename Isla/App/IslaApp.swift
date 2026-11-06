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
        MenuBarExtra(isInserted: $prefs.showMenuBarIcon) {
            MenuBarContent()
        } label: {
            Image(nsImage: IslaGlyph.menuBarImage)
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
        Button("AI Agents") { NotchManager.shared.open(.agents) }

        // Agents at work or waiting, one click from their app.
        let agents = AgentMonitor.shared.sessions.filter { $0.state != .idle }.prefix(5)
        if !agents.isEmpty {
            Divider()
            ForEach(Array(agents)) { session in
                Button { AgentMonitor.shared.bringToFront(session) } label: {
                    Label {
                        Text("\(Self.menuName(session)) — \(Text(session.state.title))")
                    } icon: {
                        Image(systemName: session.state.symbol)
                    }
                }
            }
        }

        if media.hasActiveMedia, let info = media.info {
            Divider()
            Text("\(info.title) — \(info.artist)")
            Button(media.isPlaying ? "Pause" : "Play") { media.togglePlayPause() }
            Button("Next Track") { media.next() }
        }

        Divider()
        Button(QuickActions.shared.keepAwake ? "Stop Keeping Awake" : "Keep Mac Awake") { QuickActions.shared.toggleKeepAwake() }
        Button("Pick a Color") { QuickActions.shared.pickColor() }
        Button("Capture to Shelf") { QuickActions.shared.captureScreenshot() }
        Divider()
        Button(UpdateManager.shared.availableVersion == nil ? "Check for Updates…" : "Update Available…") {
            UpdateManager.shared.checkForUpdates()
        }

        Divider()
        Button("Settings…") { SettingsWindowController.shared.show() }
            .keyboardShortcut(",")
        Button("About Isla") { SettingsWindowController.shared.show(pane: .about) }
        Divider()
        Button("Quit Isla") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// The session's own title tells two agents in one folder apart; the folder otherwise.
    private static func menuName(_ session: AgentSession) -> String {
        let name = session.title ?? session.project ?? session.tool.name
        return name.count > 42 ? String(name.prefix(41)) + "…" : name
    }
}
