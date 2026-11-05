//
//  LiveActivity.swift
//  Isla
//
//  Live activities grow out of the closed notch: long-running ones (music,
//  timers, downloads, meetings) stay while they matter, and short events
//  (volume, charging, AirPods) appear briefly and take priority.
//

import SwiftUI

enum HUDKind: String, Equatable {
    case volume, brightness, keyboardBacklight

    func symbol(for value: Double, muted: Bool) -> String {
        switch self {
        case .volume:
            if muted || value <= 0.001 { return "speaker.slash.fill" }
            return value < 0.34 ? "speaker.wave.1.fill" : value < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardBacklight:
            return value <= 0.001 ? "light.min" : "light.max"
        }
    }
}

enum DeviceKind: String, Equatable, Codable {
    case airpods, airpodsPro, airpodsMax, beats, headphones, speaker, keyboard, mouse, trackpad, gamepad, phone, generic

    var symbol: String {
        switch self {
        case .airpods: "airpods.gen3"
        case .airpodsPro: "airpods.pro"
        case .airpodsMax: "airpods.max"
        case .beats: "beats.headphones"
        case .headphones: "headphones"
        case .speaker: "hifispeaker.fill"
        case .keyboard: "keyboard.fill"
        case .mouse: "magicmouse.fill"
        case .trackpad: "rectangle.and.hand.point.up.left.fill"
        case .gamepad: "gamecontroller.fill"
        case .phone: "iphone"
        case .generic: "dot.radiowaves.left.and.right"
        }
    }

    static func guess(name: String, majorClass: UInt32 = 0, minorClass: UInt32 = 0) -> DeviceKind {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return .airpodsMax }
        if lower.contains("airpods pro") { return .airpodsPro }
        if lower.contains("airpods") { return .airpods }
        if lower.contains("beats") || lower.contains("powerbeats") { return .beats }
        if lower.contains("keyboard") { return .keyboard }
        if lower.contains("trackpad") { return .trackpad }
        if lower.contains("mouse") { return .mouse }
        if lower.contains("controller") || lower.contains("dualsense") || lower.contains("xbox") { return .gamepad }
        if lower.contains("iphone") { return .phone }
        if lower.contains("speaker") || lower.contains("homepod") || lower.contains("boom") { return .speaker }
        if lower.contains("buds") || lower.contains("headphone") || lower.contains("wh-") || lower.contains("bose") { return .headphones }
        // Bluetooth major class 0x04 = audio/video, 0x05 = peripheral.
        if majorClass == 0x04 { return .headphones }
        if majorClass == 0x05 { return minorClass & 0x10 != 0 ? .keyboard : .mouse }
        return .generic
    }
}

enum LiveActivityKind: Equatable {
    case nowPlaying
    case trackChanged
    case power(level: Int, charging: Bool, pluggedIn: Bool)
    case lowBattery(level: Int)
    case device(name: String, device: DeviceKind, connected: Bool, battery: Int?)
    case hud(HUDKind, value: Double, muted: Bool)
    case timer
    case timerFinished(label: String)
    case download(name: String, progress: Double?)
    case downloadFinished(name: String, url: URL)
    case meeting(title: String, start: Date, url: URL?)
    case capsLock(Bool)
    case shelf(count: Int)
    case message(symbol: String, title: String)
    /// AI agents working; the views read the details from `AgentMonitor`.
    case agents
    case agentFinished(toolID: String, title: String, needsYou: Bool)

    /// Activities in the same category update in place instead of re-animating.
    var category: String {
        switch self {
        case .nowPlaying: "media"
        case .trackChanged: "track"
        case .power, .lowBattery: "power"
        case .device: "device"
        case .hud(let kind, _, _): "hud-\(kind.rawValue)"
        case .timer: "timer"
        case .timerFinished: "timer-finished"
        case .download, .downloadFinished: "download"
        case .meeting: "meeting"
        case .capsLock: "caps"
        case .shelf: "shelf"
        case .message: "message"
        case .agents: "agents"
        case .agentFinished: "agent-finished"
        }
    }

    /// Extra height below the camera housing for activities with a detail row.
    var detailHeight: CGFloat {
        switch self {
        case .trackChanged: 46
        case .hud: 30
        case .device: 0
        case .timerFinished, .downloadFinished, .lowBattery: 0
        case .meeting: 0
        default: 0
        }
    }

    /// Width of the "ear" content on each side of the camera housing.
    func earWidths(notchHeight: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let square = notchHeight + 6
        switch self {
        case .nowPlaying: return (square, square)
        case .trackChanged: return (square + 8, square + 8)
        case .power: return (96, 64)
        case .lowBattery: return (110, 64)
        case .device(_, _, _, let battery): return (battery == nil ? 150 : 150, battery == nil ? 34 : 58)
        case .hud: return (square, square + 6)
        case .timer: return (square + 34, 70)
        case .timerFinished: return (160, 76)
        case .download: return (130, 58)
        case .downloadFinished: return (150, 44)
        case .meeting: return (160, 74)
        case .capsLock: return (110, 34)
        case .shelf: return (128, 40)
        case .message: return (140, 34)
        case .agents: return (square + 100, 52)
        case .agentFinished: return (150, 64)
        }
    }
}

struct LiveActivity: Identifiable, Equatable {
    var id: String
    var kind: LiveActivityKind

    init(_ kind: LiveActivityKind, id: String? = nil) {
        self.kind = kind
        self.id = id ?? kind.category
    }
}

@Observable
@MainActor
final class LiveActivityCenter {
    static let shared = LiveActivityCenter()

    private(set) var transient: LiveActivity?
    /// Bumped to make an already-visible activity "pulse" again.
    private(set) var pulse = 0
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    private init() {}

    /// The activity drawn around the closed notch, if any.
    var presented: LiveActivity? {
        transient ?? persistent
    }

    var persistent: LiveActivity? {
        let prefs = Preferences.shared
        if prefs.activityTimers, TimerStore.shared.isAnyRunning {
            return LiveActivity(.timer)
        }
        if prefs.activityDownloads, let download = DownloadsWatcher.shared.activeDownload {
            return LiveActivity(.download(name: download.name, progress: download.progress))
        }
        if prefs.activityMeetings, let meeting = CalendarService.shared.imminentMeeting {
            return LiveActivity(.meeting(title: meeting.title, start: meeting.start, url: meeting.meetingURL))
        }
        if prefs.activityAgents, AgentMonitor.shared.hasActiveAgents {
            return LiveActivity(.agents)
        }
        if prefs.activityMedia, NowPlayingService.shared.hasActiveMedia, NowPlayingService.shared.isPlaying {
            return LiveActivity(.nowPlaying)
        }
        return nil
    }

    func post(_ kind: LiveActivityKind, duration: TimeInterval = 2.4) {
        if transient?.kind.category == kind.category {
            transient?.kind = kind
        } else {
            transient = LiveActivity(kind)
        }
        pulse &+= 1
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.transient = nil
        }
    }

    func dismissTransient() {
        dismissTask?.cancel()
        transient = nil
    }
}
