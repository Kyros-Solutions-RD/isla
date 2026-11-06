//
//  Preferences.swift
//  Isla
//
//  Every user-facing option lives here. Values persist to UserDefaults the
//  moment they change, and views observe them through Observation.
//

import SwiftUI

enum NotchStyle: String, CaseIterable, Identifiable, Codable {
    case liquidGlass
    case classic

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .classic: "Classic Black"
        }
    }
}

enum PanelSize: String, CaseIterable, Identifiable, Codable {
    case compact, regular, large

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        case .large: "Large"
        }
    }

    var size: CGSize {
        switch self {
        case .compact: CGSize(width: 660, height: 236)
        case .regular: CGSize(width: 740, height: 262)
        case .large: CGSize(width: 840, height: 300)
        }
    }
}

enum DisplayPlacement: String, CaseIterable, Identifiable, Codable {
    case allDisplays, mainDisplay, notchedDisplays

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .allDisplays: "All displays"
        case .mainDisplay: "Main display only"
        case .notchedDisplays: "Displays with a notch"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
}

enum HomeWidget: String, CaseIterable, Identifiable, Codable {
    case media, calendar, weather, timer, battery, shortcuts, shelf, note, actions, agents, notifications

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .media: "Now Playing"
        case .calendar: "Up Next"
        case .weather: "Weather"
        case .timer: "Focus Timer"
        case .battery: "Battery & Devices"
        case .shortcuts: "Shortcuts"
        case .shelf: "Shelf"
        case .note: "Quick Note"
        case .actions: "Quick Actions"
        case .agents: "AI Agents"
        case .notifications: "Notifications"
        }
    }

    var symbol: String {
        switch self {
        case .media: "play.circle.fill"
        case .calendar: "calendar"
        case .weather: "cloud.sun.fill"
        case .timer: "timer"
        case .battery: "battery.75percent"
        case .shortcuts: "square.stack.3d.up.fill"
        case .shelf: "tray.full.fill"
        case .note: "note.text"
        case .actions: "bolt.fill"
        case .agents: "sparkles"
        case .notifications: "bell.badge.fill"
        }
    }

    /// Relative width in the Nook grid.
    var span: CGFloat { self == .media ? 2 : 1 }
}

@Observable
@MainActor
final class Preferences {
    static let shared = Preferences()

    @ObservationIgnored private let defaults = UserDefaults.standard

    // MARK: General
    var hasCompletedOnboarding: Bool { didSet { set(hasCompletedOnboarding, "hasCompletedOnboarding") } }
    var showMenuBarIcon: Bool { didSet { set(showMenuBarIcon, "showMenuBarIcon") } }
    var displayPlacement: DisplayPlacement { didSet { set(displayPlacement.rawValue, "displayPlacement") } }
    var hideInFullScreen: Bool { didSet { set(hideInFullScreen, "hideInFullScreen") } }
    var openOnHover: Bool { didSet { set(openOnHover, "openOnHover") } }
    var hoverDelay: Double { didSet { set(hoverDelay, "hoverDelay") } }
    var closeOnMouseExit: Bool { didSet { set(closeOnMouseExit, "closeOnMouseExit") } }
    var hapticsEnabled: Bool { didSet { set(hapticsEnabled, "hapticsEnabled") } }
    var gesturesEnabled: Bool { didSet { set(gesturesEnabled, "gesturesEnabled") } }
    var rememberLastTab: Bool { didSet { set(rememberLastTab, "rememberLastTab") } }

    // MARK: Appearance
    var notchStyle: NotchStyle { didSet { set(notchStyle.rawValue, "notchStyle") } }
    var glassTint: Double { didSet { set(glassTint, "glassTint") } }
    var panelSize: PanelSize { didSet { set(panelSize.rawValue, "panelSize") } }
    var showShadow: Bool { didSet { set(showShadow, "showShadow") } }
    var tintWithArtwork: Bool { didSet { set(tintWithArtwork, "tintWithArtwork") } }

    // MARK: Nook
    var enabledTabs: [NotchTab] { didSet { setCodable(enabledTabs, "enabledTabs") } }
    var homeWidgets: [HomeWidget] { didSet { setCodable(homeWidgets, "homeWidgets") } }
    var lastTab: NotchTab { didSet { set(lastTab.rawValue, "lastTab") } }

    // MARK: Live activities
    var activityMedia: Bool { didSet { set(activityMedia, "activityMedia") } }
    var activityTrackChange: Bool { didSet { set(activityTrackChange, "activityTrackChange") } }
    var activityBattery: Bool { didSet { set(activityBattery, "activityBattery") } }
    var activityBluetooth: Bool { didSet { set(activityBluetooth, "activityBluetooth") } }
    var activityTimers: Bool { didSet { set(activityTimers, "activityTimers") } }
    var activityDownloads: Bool { didSet { set(activityDownloads, "activityDownloads") } }
    var activityMeetings: Bool { didSet { set(activityMeetings, "activityMeetings") } }
    var activityCapsLock: Bool { didSet { set(activityCapsLock, "activityCapsLock") } }
    var activityHUD: Bool { didSet { set(activityHUD, "activityHUD") } }
    /// A second ongoing activity shows as a bubble beside the island.
    var activitySecondary: Bool { didSet { set(activitySecondary, "activitySecondary") } }
    var replaceSystemHUD: Bool { didSet { set(replaceSystemHUD, "replaceSystemHUD") } }
    var lowBatteryThreshold: Int { didSet { set(lowBatteryThreshold, "lowBatteryThreshold") } }
    var meetingLeadMinutes: Int { didSet { set(meetingLeadMinutes, "meetingLeadMinutes") } }

    // MARK: Media
    var lyricsEnabled: Bool { didSet { set(lyricsEnabled, "lyricsEnabled") } }
    var showVisualizer: Bool { didSet { set(showVisualizer, "showVisualizer") } }
    var lyricsOnIsland: Bool { didSet { set(lyricsOnIsland, "lyricsOnIsland") } }
    var checkForUpdates: Bool { didSet { set(checkForUpdates, "checkForUpdates") } }

    // MARK: Shelf
    var rememberShelf: Bool { didSet { set(rememberShelf, "rememberShelf") } }
    var pocketEnabled: Bool { didSet { set(pocketEnabled, "pocketEnabled") } }
    var openShelfOnDrag: Bool { didSet { set(openShelfOnDrag, "openShelfOnDrag") } }

    // MARK: Clipboard
    var clipboardEnabled: Bool { didSet { set(clipboardEnabled, "clipboardEnabled") } }
    var clipboardLimit: Int { didSet { set(clipboardLimit, "clipboardLimit") } }
    var clipboardAutoPaste: Bool { didSet { set(clipboardAutoPaste, "clipboardAutoPaste") } }
    var clipboardIgnoredApps: [String] { didSet { setCodable(clipboardIgnoredApps, "clipboardIgnoredApps") } }

    // MARK: Calendar
    var hiddenCalendarIDs: [String] { didSet { setCodable(hiddenCalendarIDs, "hiddenCalendarIDs") } }
    var remindersListID: String { didSet { set(remindersListID, "remindersListID") } }

    // MARK: Weather
    var temperatureUnit: TemperatureUnit { didSet { set(temperatureUnit.rawValue, "temperatureUnit") } }

    // MARK: Timers
    var pomodoroFocusMinutes: Int { didSet { set(pomodoroFocusMinutes, "pomodoroFocusMinutes") } }
    var pomodoroShortBreakMinutes: Int { didSet { set(pomodoroShortBreakMinutes, "pomodoroShortBreakMinutes") } }
    var pomodoroLongBreakMinutes: Int { didSet { set(pomodoroLongBreakMinutes, "pomodoroLongBreakMinutes") } }
    var pomodoroCyclesBeforeLongBreak: Int { didSet { set(pomodoroCyclesBeforeLongBreak, "pomodoroCyclesBeforeLongBreak") } }
    var timerSound: String { didSet { set(timerSound, "timerSound") } }

    // MARK: Teleprompter
    var prompterSpeed: Double { didSet { set(prompterSpeed, "prompterSpeed") } }
    var prompterFontSize: Double { didSet { set(prompterFontSize, "prompterFontSize") } }
    var prompterMirror: Bool { didSet { set(prompterMirror, "prompterMirror") } }

    // MARK: AI agents
    var activityAgents: Bool { didSet { set(activityAgents, "activityAgents") } }
    var agentsNotifyFinished: Bool { didSet { set(agentsNotifyFinished, "agentsNotifyFinished") } }
    /// System sound played with that moment; empty for silence (the default).
    var agentsSound: String { didSet { set(agentsSound, "agentsSound") } }
    var agentsShowSteps: Bool { didSet { set(agentsShowSteps, "agentsShowSteps") } }
    var agentsLocalModels: Bool { didSet { set(agentsLocalModels, "agentsLocalModels") } }
    var agentsCustomCommands: [String] { didSet { setCodable(agentsCustomCommands, "agentsCustomCommands") } }

    // MARK: Notifications
    /// Mirror other apps' notifications in the notch (needs Accessibility).
    var notificationsEnabled: Bool { didSet { set(notificationsEnabled, "notificationsEnabled") } }
    /// Show only the app until the pointer rests on the island.
    var notificationsHideContent: Bool { didSet { set(notificationsHideContent, "notificationsHideContent") } }
    /// Close the system banner once the notch shows it.
    var notificationsHideBanner: Bool { didSet { set(notificationsHideBanner, "notificationsHideBanner") } }
    /// System sound played when one arrives; empty for silence (the default: the app already plays its own).
    var notificationsSound: String { didSet { set(notificationsSound, "notificationsSound") } }
    /// Keep the recent ones (in memory only) for the Nook widget.
    var notificationsHistory: Bool { didSet { set(notificationsHistory, "notificationsHistory") } }
    /// Apps whose notifications stay out of the notch (bundle IDs, or "name:<App>").
    var notificationsMutedApps: [String] { didSet { setCodable(notificationsMutedApps, "notificationsMutedApps") } }

    // MARK: Shortcuts
    var favoriteShortcuts: [String] { didSet { setCodable(favoriteShortcuts, "favoriteShortcuts") } }

    // MARK: Keyboard
    var toggleHotKey: KeyCombo? { didSet { setCodable(toggleHotKey, "toggleHotKey") } }
    var clipboardHotKey: KeyCombo? { didSet { setCodable(clipboardHotKey, "clipboardHotKey") } }
    var shelfHotKey: KeyCombo? { didSet { setCodable(shelfHotKey, "shelfHotKey") } }

    private init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        func double(_ key: String, _ fallback: Double) -> Double { d.object(forKey: key) as? Double ?? fallback }
        func int(_ key: String, _ fallback: Int) -> Int { d.object(forKey: key) as? Int ?? fallback }
        func string(_ key: String, _ fallback: String) -> String { d.string(forKey: key) ?? fallback }
        func codable<T: Decodable>(_ key: String, _ fallback: T) -> T {
            guard let data = d.data(forKey: key), let value = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
            return value
        }

        hasCompletedOnboarding = bool("hasCompletedOnboarding", false)
        showMenuBarIcon = bool("showMenuBarIcon", true)
        displayPlacement = DisplayPlacement(rawValue: string("displayPlacement", "")) ?? .allDisplays
        hideInFullScreen = bool("hideInFullScreen", true)
        openOnHover = bool("openOnHover", true)
        hoverDelay = double("hoverDelay", 0.18)
        closeOnMouseExit = bool("closeOnMouseExit", true)
        hapticsEnabled = bool("hapticsEnabled", true)
        gesturesEnabled = bool("gesturesEnabled", true)
        rememberLastTab = bool("rememberLastTab", true)

        notchStyle = NotchStyle(rawValue: string("notchStyle", "")) ?? .liquidGlass
        glassTint = double("glassTint", 0.42)
        panelSize = PanelSize(rawValue: string("panelSize", "")) ?? .regular
        showShadow = bool("showShadow", true)
        tintWithArtwork = bool("tintWithArtwork", true)

        enabledTabs = codable("enabledTabs", NotchTab.defaultTabs)
        homeWidgets = codable("homeWidgets", [HomeWidget.media, .calendar, .weather])
        lastTab = NotchTab(rawValue: string("lastTab", "")) ?? .home

        activityMedia = bool("activityMedia", true)
        activityTrackChange = bool("activityTrackChange", true)
        activityBattery = bool("activityBattery", true)
        activityBluetooth = bool("activityBluetooth", true)
        activityTimers = bool("activityTimers", true)
        activityDownloads = bool("activityDownloads", true)
        activityMeetings = bool("activityMeetings", true)
        activityCapsLock = bool("activityCapsLock", true)
        activityHUD = bool("activityHUD", true)
        activitySecondary = bool("activitySecondary", true)
        replaceSystemHUD = bool("replaceSystemHUD", false)
        lowBatteryThreshold = int("lowBatteryThreshold", 20)
        meetingLeadMinutes = int("meetingLeadMinutes", 5)

        lyricsEnabled = bool("lyricsEnabled", true)
        showVisualizer = bool("showVisualizer", true)
        lyricsOnIsland = bool("lyricsOnIsland", false)
        checkForUpdates = bool("checkForUpdates", true)

        rememberShelf = bool("rememberShelf", true)
        pocketEnabled = bool("pocketEnabled", true)
        openShelfOnDrag = bool("openShelfOnDrag", true)

        clipboardEnabled = bool("clipboardEnabled", true)
        clipboardLimit = int("clipboardLimit", 150)
        clipboardAutoPaste = bool("clipboardAutoPaste", false)
        clipboardIgnoredApps = codable("clipboardIgnoredApps", ClipboardStore.defaultIgnoredApps)

        hiddenCalendarIDs = codable("hiddenCalendarIDs", [String]())
        remindersListID = string("remindersListID", "")

        temperatureUnit = TemperatureUnit(rawValue: string("temperatureUnit", "")) ??
            (Locale.current.measurementSystem == .us ? .fahrenheit : .celsius)

        pomodoroFocusMinutes = int("pomodoroFocusMinutes", 25)
        pomodoroShortBreakMinutes = int("pomodoroShortBreakMinutes", 5)
        pomodoroLongBreakMinutes = int("pomodoroLongBreakMinutes", 15)
        pomodoroCyclesBeforeLongBreak = int("pomodoroCyclesBeforeLongBreak", 4)
        timerSound = string("timerSound", "Glass")

        prompterSpeed = double("prompterSpeed", 34)
        prompterFontSize = double("prompterFontSize", 22)
        prompterMirror = bool("prompterMirror", false)

        activityAgents = bool("activityAgents", true)
        agentsNotifyFinished = bool("agentsNotifyFinished", true)
        agentsSound = string("agentsSound", "")
        agentsShowSteps = bool("agentsShowSteps", true)
        agentsLocalModels = bool("agentsLocalModels", true)
        agentsCustomCommands = codable("agentsCustomCommands", [String]())

        notificationsEnabled = bool("notificationsEnabled", true)
        notificationsHideContent = bool("notificationsHideContent", false)
        notificationsHideBanner = bool("notificationsHideBanner", false)
        notificationsSound = string("notificationsSound", "")
        notificationsHistory = bool("notificationsHistory", true)
        notificationsMutedApps = codable("notificationsMutedApps", [String]())

        favoriteShortcuts = codable("favoriteShortcuts", [String]())

        toggleHotKey = codable("toggleHotKey", Optional(KeyCombo.defaultToggle))
        clipboardHotKey = codable("clipboardHotKey", Optional(KeyCombo.defaultClipboard))
        shelfHotKey = codable("shelfHotKey", Optional<KeyCombo>.none)

        // The AI tab arrived in an update: add it once for people who already chose their tabs.
        if !bool("agentsTabIntroduced", false) {
            if d.data(forKey: "enabledTabs") != nil, !enabledTabs.contains(.agents) {
                enabledTabs.insert(.agents, at: min(1, enabledTabs.count))
                setCodable(enabledTabs, "enabledTabs")
            }
            d.set(true, forKey: "agentsTabIntroduced")
        }
    }

    private func set(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private func setCodable<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    func resetAll() {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
    }

    /// Tabs that are enabled and visible in the header, in the user's order.
    var visibleTabs: [NotchTab] {
        let tabs = enabledTabs.filter { NotchTab.allCases.contains($0) }
        return tabs.isEmpty ? [.home] : tabs
    }
}
