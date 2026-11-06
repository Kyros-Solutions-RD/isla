//
//  NotificationsSettingsPane.swift
//  Isla
//
//  Settings › Notifications.
//

import AppKit
import SwiftUI

struct NotificationsPane: View {
    @Bindable private var prefs = Preferences.shared
    private let mirror = NotificationMirror.shared
    private let permissions = PermissionCenter.shared
    @State private var apps: [NotificationAppInfo] = []

    private static let sounds = ["Glass", "Hero", "Ping", "Pop", "Purr", "Submarine", "Tink", "Blow", "Bottle", "Frog", "Funk", "Morse", "Sosumi"]

    var body: some View {
        Form {
            Section {
                Toggle("Show notifications in the notch", isOn: $prefs.notificationsEnabled)
                    .onChange(of: prefs.notificationsEnabled) { _, on in
                        if on && !AXIsProcessTrusted() { permissions.request(.accessibility) }
                        mirror.refresh()
                    }
                if prefs.notificationsEnabled && !permissions.isGranted(.accessibility) {
                    PermissionHint(kind: .accessibility)
                }
                Picker("Sound", selection: $prefs.notificationsSound) {
                    Text("No sound").tag("")
                    Divider()
                    ForEach(Self.sounds, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .onChange(of: prefs.notificationsSound) { _, name in
                    if !name.isEmpty { NSSound(named: NSSound.Name(name))?.play() }
                }
                .disabled(!prefs.notificationsEnabled)
                Button("Preview") { mirror.preview() }
                    .disabled(!prefs.notificationsEnabled)
            } header: {
                Text("In the notch")
            } footer: {
                Text("Messages, WhatsApp, Mail and every other app: their notifications come out of the camera. Click one to open it, rest the pointer on it to read it all, or swipe it away.")
            }

            Section {
                Toggle("Hide the content", isOn: $prefs.notificationsHideContent)
                Toggle("Close the system banner", isOn: $prefs.notificationsHideBanner)
            } header: {
                Text("Privacy and banners")
            } footer: {
                Text("With the content hidden, the island shows only the app until you rest the pointer on it. Closing the system banner also takes the notification out of Notification Center; the Nook widget keeps the recent ones.")
            }

            Section {
                LabeledContent("Focus and Do Not Disturb") {
                    Label("Always respected", systemImage: "moon.fill")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Isla shows only what macOS lets through: when a Focus or Do Not Disturb silences an app, it stays quiet in the notch too.")
            }

            Section {
                Toggle("Keep the recent ones", isOn: $prefs.notificationsHistory)
                    .onChange(of: prefs.notificationsHistory) { _, on in if !on { mirror.clearHistory() } }
                if !prefs.homeWidgets.contains(.notifications) {
                    Button("Add the Widget to the Nook") { prefs.homeWidgets.append(.notifications) }
                        .disabled(prefs.homeWidgets.reduce(0) { $0 + $1.span } >= 4)
                }
                Button("Clear History") { mirror.clearHistory() }
                    .disabled(mirror.history.isEmpty)
            } header: {
                Text("Recent")
            } footer: {
                Text("Kept in memory only: never written to disk, and gone when Isla quits.")
            }

            Section {
                if apps.isEmpty {
                    Text("Apps show up here once they can send notifications.")
                        .foregroundStyle(.secondary)
                }
                ForEach(apps, id: \.key) { app in
                    Toggle(isOn: binding(for: app)) {
                        Label {
                            Text(verbatim: app.name)
                        } icon: {
                            NotificationAppIcon(app: app, size: 20)
                        }
                    }
                }
            } header: {
                Text("Apps")
            } footer: {
                Text("Turn an app off to keep its notifications out of the notch. They still reach Notification Center as usual.")
            }

            Section {
                Label("Isla reads the banners macOS draws, through Accessibility. Nothing is saved and nothing leaves your Mac.", systemImage: "lock.fill")
            }
        }
        .onAppear {
            NotificationApps.shared.prepare()
            apps = NotificationApps.shared.knownApps(including: mirror.seenApps)
        }
    }

    private func binding(for app: NotificationAppInfo) -> Binding<Bool> {
        Binding {
            !prefs.notificationsMutedApps.contains(app.key)
        } set: { shown in
            if shown {
                prefs.notificationsMutedApps.removeAll { $0 == app.key }
            } else if !prefs.notificationsMutedApps.contains(app.key) {
                prefs.notificationsMutedApps.append(app.key)
            }
        }
    }
}
