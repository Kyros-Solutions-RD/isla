//
//  SettingsView.swift
//  Isla
//

import AppKit
import EventKit
import ServiceManagement
import SwiftUI

struct SettingsRootView: View {
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                ForEach(Array(SettingsPane.groups.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group) { pane in
                            NavigationLink(value: pane) {
                                Label {
                                    Text(pane.title)
                                } icon: {
                                    SettingsIcon(symbol: pane.symbol, tint: pane.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 260)
        } detail: {
            Group {
                switch navigation.selection ?? .general {
                case .general: GeneralPane()
                case .appearance: AppearancePane()
                case .nook: NookPane()
                case .activities: ActivitiesPane()
                case .notifications: NotificationsPane()
                case .agents: AgentsPane()
                case .media: MediaPane()
                case .shelf: ShelfPane()
                case .clipboard: ClipboardPane()
                case .calendar: CalendarPane()
                case .focus: FocusPane()
                case .keyboard: KeyboardPane()
                case .permissions: PermissionsPane()
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigation.selection?.title ?? "General")
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

struct SettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.gradient))
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Bindable private var prefs = Preferences.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Open Isla at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Show icon in the menu bar", isOn: $prefs.showMenuBarIcon)
                Toggle("Check for updates automatically", isOn: $prefs.checkForUpdates)
                    .onChange(of: prefs.checkForUpdates) { _, on in UpdateManager.shared.automaticallyChecks = on }
            }

            Section("Displays") {
                Picker("Show the notch on", selection: $prefs.displayPlacement) {
                    ForEach(DisplayPlacement.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: prefs.displayPlacement) { NotchManager.shared.rebuild() }
                Toggle("Hide when an app is full screen", isOn: $prefs.hideInFullScreen)
                    .onChange(of: prefs.hideInFullScreen) { NotchManager.shared.updateFullScreenVisibility() }
                Text("On displays without a notch, Isla draws a matching island at the top of the screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Open when the pointer rests on the notch", isOn: $prefs.openOnHover)
                if prefs.openOnHover {
                    LabeledContent("Delay") {
                        Slider(value: $prefs.hoverDelay, in: 0...0.8, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Instant").font(.caption)
                        } maximumValueLabel: {
                            Text("Relaxed").font(.caption)
                        }
                        .frame(maxWidth: 260)
                    }
                }
                Toggle("Close when the pointer leaves", isOn: $prefs.closeOnMouseExit)
                Toggle("Trackpad gestures", isOn: $prefs.gesturesEnabled)
                Text("Swipe down on the notch to open it, swipe up to close, and swipe sideways to change tracks.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Haptic feedback", isOn: $prefs.hapticsEnabled)
                Toggle("Reopen the last tab", isOn: $prefs.rememberLastTab)
            }

            Section {
                Button("Show Welcome Tour…") { OnboardingWindowController.shared.show() }
                Button("Reset All Settings…", role: .destructive) {
                    let alert = NSAlert()
                    alert.messageText = String(localized: "Reset all settings?")
                    alert.informativeText = String(localized: "Isla will quit. Your notes, shelf and clipboard history are kept.")
                    alert.addButton(withTitle: String(localized: "Reset"))
                    alert.addButton(withTitle: String(localized: "Cancel"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        prefs.resetAll()
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
}

// MARK: - Appearance

private struct AppearancePane: View {
    @Bindable private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section("Style") {
                HStack(spacing: 16) {
                    ForEach(NotchStyle.allCases) { style in
                        StylePreview(style: style, selected: prefs.notchStyle == style)
                            .onTapGesture { withAnimation(.smooth) { prefs.notchStyle = style } }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                if prefs.notchStyle == .liquidGlass {
                    LabeledContent("Glass tint") {
                        Slider(value: $prefs.glassTint, in: 0...0.85) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Clear").font(.caption)
                        } maximumValueLabel: {
                            Text("Dark").font(.caption)
                        }
                        .frame(maxWidth: 260)
                    }
                }
                Toggle("Tint with album artwork", isOn: $prefs.tintWithArtwork)
                Toggle("Drop shadow", isOn: $prefs.showShadow)
            }

            Section("Size") {
                Picker("Open panel", selection: $prefs.panelSize) {
                    ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                PanelSizePreview(size: prefs.panelSize, style: prefs.notchStyle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            Section {
                Button("Preview the Nook") { NotchManager.shared.open(.home) }
            }
        }
    }
}

private struct StylePreview: View {
    let style: NotchStyle
    let selected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.4), Color(red: 0.45, green: 0.3, blue: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Group {
                    if style == .liquidGlass {
                        NotchShape(topRadius: 8, bottomRadius: 18)
                            .fill(.clear)
                            .glassEffect(.regular.tint(.black.opacity(0.25)), in: NotchShape(topRadius: 8, bottomRadius: 18))
                    } else {
                        NotchShape(topRadius: 8, bottomRadius: 18).fill(.black)
                    }
                }
                .frame(width: 150, height: 58)
                .overlay(alignment: .top) {
                    NotchShape(topRadius: 4, bottomRadius: 6).fill(.black).frame(width: 52, height: 12)
                }
            }
            .frame(width: 190, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 3 : 1)
            }
            Text(style.title)
                .font(.callout.weight(selected ? .semibold : .regular))
        }
        .contentShape(Rectangle())
    }
}

/// The top of a Mac screen at a fifth of its size, with the Nook open at the chosen size.
/// Changing the size makes the panel spring to it, the way the real one opens.
private struct PanelSizePreview: View {
    let size: PanelSize
    let style: NotchStyle
    private let scale: CGFloat = 0.22

    var body: some View {
        let panel = CGSize(width: size.size.width * scale, height: size.size.height * scale)
        let shape = NotchShape(topRadius: 4, bottomRadius: 9)

        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.4), Color(red: 0.45, green: 0.3, blue: 0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.black.opacity(0.22)).frame(height: 7)
            ZStack(alignment: .top) {
                if style == .liquidGlass {
                    Color.clear.glassEffect(.regular.tint(.black.opacity(0.3)), in: shape)
                } else {
                    shape.fill(.black)
                }
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(.white.opacity(0.13))
                            .frame(maxWidth: index == 0 ? .infinity : nil)
                            .frame(width: index == 0 ? nil : panel.width * 0.22)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.top, 10)
                .padding(.bottom, 6)
                NotchShape(topRadius: 2, bottomRadius: 3).fill(.black).frame(width: 40, height: 7)
            }
            .frame(width: panel.width, height: panel.height)
        }
        .frame(width: 1512 * scale, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: "\(Int(size.size.width)) × \(Int(size.size.height)) pt")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
                .padding(6)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Nook

private struct NookPane: View {
    @Bindable private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(orderedTabs) { tab in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            Image(systemName: tab.symbol).frame(width: 20).foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title)
                                Text(tab.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: binding(for: tab))
                                .labelsHidden()
                                .disabled(tab == .home)
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: moveTabs)
                }
                .frame(minHeight: 380)
            } header: {
                Text("Tabs")
            } footer: {
                Text("Drag to reorder. ⌘1…⌘0 switch tabs while the Nook is open.")
            }

            Section {
                ForEach(prefs.homeWidgets) { widget in
                    HStack {
                        Image(systemName: widget.symbol).frame(width: 20).foregroundStyle(Color.accentColor)
                        Text(widget.title)
                        Spacer()
                        Button { move(widget, by: -1) } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless)
                            .disabled(prefs.homeWidgets.first == widget)
                        Button { move(widget, by: 1) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless)
                            .disabled(prefs.homeWidgets.last == widget)
                        Button(role: .destructive) {
                            prefs.homeWidgets.removeAll { $0 == widget }
                        } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            .disabled(prefs.homeWidgets.count == 1)
                    }
                }
                Menu("Add Widget") {
                    ForEach(HomeWidget.allCases.filter { !prefs.homeWidgets.contains($0) }) { widget in
                        Button { prefs.homeWidgets.append(widget) } label: { Label(widget.title, systemImage: widget.symbol) }
                    }
                }
                .disabled(widgetSpan >= 4)
            } header: {
                Text("Nook widgets")
            } footer: {
                Text("The Nook fits up to four columns. Now Playing uses two.")
            }
        }
    }

    private var widgetSpan: CGFloat { prefs.homeWidgets.reduce(0) { $0 + $1.span } }

    private var orderedTabs: [NotchTab] {
        prefs.enabledTabs + NotchTab.allCases.filter { !prefs.enabledTabs.contains($0) }
    }

    private func binding(for tab: NotchTab) -> Binding<Bool> {
        Binding {
            prefs.enabledTabs.contains(tab)
        } set: { enabled in
            if enabled {
                if !prefs.enabledTabs.contains(tab) { prefs.enabledTabs.append(tab) }
            } else {
                prefs.enabledTabs.removeAll { $0 == tab }
            }
        }
    }

    private func moveTabs(from source: IndexSet, to destination: Int) {
        var all = orderedTabs
        all.move(fromOffsets: source, toOffset: destination)
        let enabled = Set(prefs.enabledTabs)
        prefs.enabledTabs = all.filter { enabled.contains($0) }
    }

    private func move(_ widget: HomeWidget, by offset: Int) {
        guard let index = prefs.homeWidgets.firstIndex(of: widget) else { return }
        let target = index + offset
        guard prefs.homeWidgets.indices.contains(target) else { return }
        prefs.homeWidgets.swapAt(index, target)
    }
}

// MARK: - Live activities

private struct ActivitiesPane: View {
    @Bindable private var prefs = Preferences.shared
    private let permissions = PermissionCenter.shared

    var body: some View {
        Form {
            Section {
                Toggle("Now Playing", isOn: $prefs.activityMedia)
                Toggle("Show the song when the track changes", isOn: $prefs.activityTrackChange)
                    .disabled(!prefs.activityMedia)
                Toggle("Timers and Pomodoro", isOn: $prefs.activityTimers)
                Toggle("Downloads", isOn: $prefs.activityDownloads)
                    .onChange(of: prefs.activityDownloads) { _, on in on ? DownloadsWatcher.shared.start() : DownloadsWatcher.shared.stop() }
                Toggle("AI agents at work", isOn: $prefs.activityAgents)
                Toggle("Upcoming meetings", isOn: $prefs.activityMeetings)
                if prefs.activityMeetings {
                    Stepper("Start \(prefs.meetingLeadMinutes) minutes before", value: $prefs.meetingLeadMinutes, in: 1...30)
                }
                Toggle("CPU and network (System monitor)", isOn: $prefs.activitySystem)
                Toggle("Show a second activity in a bubble beside the island", isOn: $prefs.activitySecondary)
            } header: {
                Text("While it matters")
            } footer: {
                Text("These stay around the notch while they are running. When two are going on, the second one waits in a small bubble beside the island; click it to open its tab.")
            }

            Section("Moments") {
                Toggle("Charging and battery", isOn: $prefs.activityBattery)
                if prefs.activityBattery {
                    Picker("Low battery alert", selection: $prefs.lowBatteryThreshold) {
                        ForEach([10, 15, 20, 25, 30], id: \.self) { Text("\($0)%").tag($0) }
                    }
                }
                Toggle("AirPods and Bluetooth devices", isOn: $prefs.activityBluetooth)
                Toggle("Caps Lock", isOn: $prefs.activityCapsLock)
                Toggle("Volume and brightness", isOn: $prefs.activityHUD)
            }

            Section {
                Toggle("Replace the system volume and brightness overlay", isOn: $prefs.replaceSystemHUD)
                    .onChange(of: prefs.replaceSystemHUD) { _, on in
                        if on && !AXIsProcessTrusted() { permissions.request(.accessibility) }
                        MediaKeyTap.shared.update()
                    }
                if prefs.replaceSystemHUD && !permissions.isGranted(.accessibility) {
                    PermissionHint(kind: .accessibility)
                }
            } footer: {
                Text("Isla handles the volume and brightness keys itself and shows a compact slider under the notch. Hold ⌥⇧ for finer steps.")
            }
        }
    }
}

struct PermissionHint: View {
    let kind: PermissionKind

    var body: some View {
        HStack {
            Label("Needs \(Text(kind.title)) access", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Spacer()
            Button("Grant…") { PermissionCenter.shared.request(kind) }
        }
    }
}

// MARK: - Media

private struct MediaPane: View {
    @Bindable private var prefs = Preferences.shared
    private let media = NowPlayingService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Synced lyrics", isOn: $prefs.lyricsEnabled)
                Toggle("Animated equalizer", isOn: $prefs.showVisualizer)
                Toggle("Show the lyric line under the island", isOn: $prefs.lyricsOnIsland)
                    .disabled(!prefs.lyricsEnabled)
            } footer: {
                Text("Lyrics come from LRCLIB, a free and open lyrics database. Only the song title, artist and album are sent.")
            }
            Section("Source") {
                LabeledContent("Now Playing") {
                    if let info = media.info {
                        Text("\(info.title) — \(media.appName ?? info.bundleIdentifier ?? "")").foregroundStyle(.secondary).lineLimit(1)
                    } else {
                        Text("Nothing playing").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Connection") {
                    Text(media.usingFallback ? "Music & Spotify (AppleScript)" : "System Now Playing")
                        .foregroundStyle(.secondary)
                }
                Text("Isla follows any app that shows up in Control Center's Now Playing: Music, Spotify, Podcasts, browsers and more.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shelf

private struct ShelfPane: View {
    @Bindable private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Open the Shelf when dragging files near the notch", isOn: $prefs.openShelfOnDrag)
                Toggle("Pocket: shake while dragging to drop anywhere", isOn: $prefs.pocketEnabled)
                Toggle("Remember files after restarting", isOn: $prefs.rememberShelf)
            } footer: {
                Text("The Shelf keeps a reference to your files; it never moves or copies them. Text, images and conversions you drop are saved in Isla's folder.")
            }
            Section {
                Button("Show Converted Files in Finder") { NSWorkspace.shared.open(FileConverter.outputFolder) }
                Button("Clear Shelf", role: .destructive) { ShelfStore.shared.clear() }
            }
        }
    }
}

// MARK: - Clipboard

private struct ClipboardPane: View {
    @Bindable private var prefs = Preferences.shared
    private let permissions = PermissionCenter.shared

    var body: some View {
        Form {
            Section {
                Toggle("Keep clipboard history", isOn: $prefs.clipboardEnabled)
                Picker("History size", selection: $prefs.clipboardLimit) {
                    ForEach([50, 100, 150, 300, 500], id: \.self) { Text("\($0) items").tag($0) }
                }
                Toggle("Paste directly into the current app", isOn: $prefs.clipboardAutoPaste)
                    .onChange(of: prefs.clipboardAutoPaste) { _, on in
                        if on && !AXIsProcessTrusted() { permissions.request(.accessibility) }
                    }
                if prefs.clipboardAutoPaste && !permissions.isGranted(.accessibility) {
                    PermissionHint(kind: .accessibility)
                }
            } footer: {
                Text("Items copied from password managers and anything marked as concealed are never saved. History stays on this Mac.")
            }

            Section("Never record from") {
                ForEach(prefs.clipboardIgnoredApps, id: \.self) { bundle in
                    HStack {
                        if let icon = NSWorkspace.shared.appIcon(bundleIdentifier: bundle) {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                        }
                        Text(NSWorkspace.shared.appName(bundleIdentifier: bundle) ?? bundle)
                        Spacer()
                        Button { prefs.clipboardIgnoredApps.removeAll { $0 == bundle } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Menu("Add App") {
                    ForEach(runningApps, id: \.self) { bundle in
                        Button(NSWorkspace.shared.appName(bundleIdentifier: bundle) ?? bundle) {
                            prefs.clipboardIgnoredApps.append(bundle)
                        }
                    }
                }
            }

            Section {
                Button("Clear Clipboard History", role: .destructive) { ClipboardStore.shared.clearHistory(keepPinned: false) }
            }
        }
    }

    private var runningApps: [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !prefs.clipboardIgnoredApps.contains($0) }
            .sorted()
    }
}

// MARK: - Calendar & Tasks

private struct CalendarPane: View {
    @Bindable private var prefs = Preferences.shared
    private let calendar = CalendarService.shared
    private let tasks = TasksStore.shared

    var body: some View {
        Form {
            Section("Calendars") {
                if calendar.authorized {
                    ForEach(calendar.calendars, id: \.calendarIdentifier) { item in
                        Toggle(isOn: Binding {
                            !prefs.hiddenCalendarIDs.contains(item.calendarIdentifier)
                        } set: { _ in
                            calendar.toggleCalendar(item)
                        }) {
                            HStack {
                                Circle().fill(Color(cgColor: item.cgColor)).frame(width: 10, height: 10)
                                Text(item.title)
                                Text(item.source.title).foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                } else {
                    PermissionHint(kind: .calendar)
                }
                Text("Google, Exchange and other accounts appear here once added in System Settings → Internet Accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Tasks") {
                if tasks.usesReminders {
                    Picker("Reminders list", selection: $prefs.remindersListID) {
                        ForEach(tasks.lists, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                    }
                    .onChange(of: prefs.remindersListID) { tasks.reload() }
                    Button("Use Local Tasks Instead") { tasks.useLocalTasks() }
                } else {
                    LabeledContent("Storage", value: String(localized: "On this Mac"))
                    Button("Sync with Reminders…") { Task { await tasks.requestRemindersAccess() } }
                }
            }
        }
    }
}

// MARK: - Focus

private struct FocusPane: View {
    @Bindable private var prefs = Preferences.shared
    private let sounds = ["Glass", "Hero", "Ping", "Purr", "Submarine", "Funk", "Blow", "Bottle", "Frog", "Morse", "Pop", "Sosumi", "Tink", "Basso"]

    var body: some View {
        Form {
            Section("Pomodoro") {
                Stepper("Focus: \(prefs.pomodoroFocusMinutes) min", value: $prefs.pomodoroFocusMinutes, in: 5...120, step: 5)
                Stepper("Short break: \(prefs.pomodoroShortBreakMinutes) min", value: $prefs.pomodoroShortBreakMinutes, in: 1...30)
                Stepper("Long break: \(prefs.pomodoroLongBreakMinutes) min", value: $prefs.pomodoroLongBreakMinutes, in: 5...60, step: 5)
                Stepper("Long break every \(prefs.pomodoroCyclesBeforeLongBreak) sessions", value: $prefs.pomodoroCyclesBeforeLongBreak, in: 2...8)
            }
            Section("Alerts") {
                Picker("Sound", selection: $prefs.timerSound) {
                    ForEach(sounds, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: prefs.timerSound) { _, name in NSSound(named: NSSound.Name(name))?.play() }
            }
        }
    }
}

// MARK: - Keyboard

private struct KeyboardPane: View {
    @Bindable private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section("Global shortcuts") {
                LabeledContent("Open or close Isla") {
                    HotKeyRecorder(combo: $prefs.toggleHotKey)
                }
                LabeledContent("Clipboard history") {
                    HotKeyRecorder(combo: $prefs.clipboardHotKey)
                }
                LabeledContent("Shelf") {
                    HotKeyRecorder(combo: $prefs.shelfHotKey)
                }
                LabeledContent("Search and calculate") {
                    HotKeyRecorder(combo: $prefs.launcherHotKey)
                }
            }
            .onChange(of: prefs.toggleHotKey) { AppDelegate.registerHotKeys() }
            .onChange(of: prefs.clipboardHotKey) { AppDelegate.registerHotKeys() }
            .onChange(of: prefs.shelfHotKey) { AppDelegate.registerHotKeys() }
            .onChange(of: prefs.launcherHotKey) { AppDelegate.registerHotKeys() }

            Section("Inside the Nook") {
                LabeledContent("Close", value: "⎋")
                LabeledContent("Switch tab", value: "⌘1 … ⌘0")
                LabeledContent("Next / previous tab", value: "⌃⇥ / ⌃⇧⇥")
                LabeledContent("Settings", value: "⌘,")
            }
        }
    }
}

struct HotKeyRecorder: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? String(localized: "Type shortcut…") : (combo?.display ?? String(localized: "Record Shortcut")))
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)

            if combo != nil {
                Button { combo = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyCenter.shared.unregister(.toggleNotch)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            if let newCombo = KeyCombo(event: event) {
                combo = newCombo
                stop()
                return nil
            }
            NSSound.beep()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        AppDelegate.registerHotKeys()
    }
}

// MARK: - Permissions

private struct PermissionsPane: View {
    private let permissions = PermissionCenter.shared

    var body: some View {
        Form {
            Section {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(kind: kind)
                }
            } header: {
                Text("Permissions")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Isla works without any of these. Each one only unlocks the feature it describes.")
                    if !permissions.isGranted(.accessibility) {
                        // A toggle left over from an older copy of Isla looks on in System Settings
                        // but no longer applies; removing it lets macOS add this copy.
                        Text("Isla already switched on in System Settings › Accessibility but not allowed here? Select it there, remove it with −, then click Allow… again.")
                    }
                }
            }

            Section("Your data") {
                Label("Notes, tasks, shelf and clipboard history are stored only on this Mac.", systemImage: "lock.fill")
                Label("No accounts, no analytics, no tracking.", systemImage: "eye.slash.fill")
                Label("Weather uses an approximate location, and lyrics send only song details.", systemImage: "network")
                Button("Show Isla's Data Folder") { NSWorkspace.shared.open(Storage.directory) }
            }
        }
        .onAppear { permissions.startWatching() }
        .onDisappear { permissions.stopWatching() }
    }
}

struct PermissionRow: View {
    let kind: PermissionKind
    private let permissions = PermissionCenter.shared

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: kind.symbol, tint: kind.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                Text(kind.reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if permissions.isGranted(kind) {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Button("Allow…") { permissions.request(kind) }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - About

private struct AboutPane: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("Isla").font(.system(size: 28, weight: .bold))
                    Text("Version \(version)").foregroundStyle(.secondary)
                    Text("Your notch, turned into an island. Free and open source.")
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Link(destination: URL(string: "https://github.com/Kyros-Solutions-RD/isla")!) {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .buttonStyle(.glass)
                        Link(destination: URL(string: "https://isla.kyrosrd.com")!) {
                            Label("Website", systemImage: "safari")
                        }
                        .buttonStyle(.glass)
                        Link(destination: URL(string: "https://github.com/Kyros-Solutions-RD/isla/issues/new")!) {
                            Label("Report an Issue", systemImage: "ladybug")
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Updates") {
                let updates = UpdateManager.shared
                LabeledContent("Installed version", value: updates.currentVersion)
                if let version = updates.availableVersion {
                    Label("Isla \(version) is available", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                if let last = updates.lastChecked {
                    LabeledContent("Last checked", value: last.formatted(.relative(presentation: .named)))
                }
                Toggle("Download updates automatically", isOn: Binding {
                    updates.automaticallyDownloads
                } set: { updates.automaticallyDownloads = $0 })
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .buttonStyle(.glassProminent)
            }

            Section("Made by") {
                LabeledContent("Kyros Solutions RD", value: String(localized: "Santo Domingo, Dominican Republic"))
                LabeledContent("License", value: "MIT")
            }

            Section("Thanks to") {
                LabeledContent("LRCLIB", value: String(localized: "Synced lyrics"))
                LabeledContent("Open-Meteo", value: String(localized: "Weather data"))
                LabeledContent("SwiftTerm", value: String(localized: "Terminal emulator (MIT)"))
                LabeledContent("Sparkle", value: String(localized: "Automatic updates (MIT)"))
            }
        }
    }
}
