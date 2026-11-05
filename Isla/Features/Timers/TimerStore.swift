//
//  TimerStore.swift
//  Isla
//
//  Pomodoro focus sessions, any number of countdown timers and a stopwatch.
//

import AppKit
import SwiftUI

struct CountdownTimer: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var duration: TimeInterval
    var endDate: Date?
    var pausedRemaining: TimeInterval?

    var isRunning: Bool { endDate != nil }
    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at date: Date) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return pausedRemaining ?? duration
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return 1 - remaining(at: date) / duration
    }
}

enum PomodoroPhase: String, Codable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short Break")
        case .longBreak: String(localized: "Long Break")
        }
    }

    var tint: Color {
        switch self {
        case .focus: .orange
        case .shortBreak: .green
        case .longBreak: .teal
        }
    }

    var symbol: String {
        switch self {
        case .focus: "brain.head.profile.fill"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "figure.walk"
        }
    }
}

struct PomodoroState: Codable, Equatable {
    var phase: PomodoroPhase = .focus
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var completedFocusSessions = 0
    var phaseDuration: TimeInterval = 25 * 60

    var isRunning: Bool { endDate != nil }
    var isStarted: Bool { endDate != nil || pausedRemaining != nil }

    func remaining(at date: Date) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return pausedRemaining ?? phaseDuration
    }
}

struct TimerDisplay {
    var label: String
    var remaining: TimeInterval
    var progress: Double
    var tint: Color
}

@Observable
@MainActor
final class TimerStore {
    static let shared = TimerStore()

    private(set) var timers: [CountdownTimer] = []
    private(set) var pomodoro = PomodoroState()
    private(set) var stopwatchStart: Date?
    private(set) var stopwatchAccumulated: TimeInterval = 0
    private(set) var finishedLabel: String?
    private(set) var focusMinutesToday: Int = 0

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var alarm: NSSound?

    private init() {
        pomodoro.phaseDuration = TimeInterval(Preferences.shared.pomodoroFocusMinutes * 60)
        focusMinutesToday = UserDefaults.standard.integer(forKey: Self.focusKey)
        startTicker()
    }

    private static var focusKey: String {
        "focusMinutes-" + Date.now.formatted(.iso8601.year().month().day())
    }

    var isAnyRunning: Bool {
        pomodoro.isRunning || timers.contains(where: \.isRunning)
    }

    var isStopwatchRunning: Bool { stopwatchStart != nil }

    func stopwatchElapsed(at date: Date) -> TimeInterval {
        stopwatchAccumulated + (stopwatchStart.map { date.timeIntervalSince($0) } ?? 0)
    }

    /// What the closed notch shows: the soonest-ending running timer.
    func primaryDisplay(at date: Date) -> TimerDisplay? {
        var candidates: [TimerDisplay] = []
        if pomodoro.isRunning {
            let remaining = pomodoro.remaining(at: date)
            candidates.append(TimerDisplay(label: pomodoro.phase.title, remaining: remaining,
                                           progress: 1 - remaining / max(1, pomodoro.phaseDuration), tint: pomodoro.phase.tint))
        }
        for timer in timers where timer.isRunning {
            candidates.append(TimerDisplay(label: timer.label, remaining: timer.remaining(at: date),
                                           progress: timer.progress(at: date), tint: .orange))
        }
        return candidates.min { $0.remaining < $1.remaining }
    }

    // MARK: Pomodoro

    func togglePomodoro() {
        if pomodoro.isRunning {
            pomodoro.pausedRemaining = pomodoro.remaining(at: .now)
            pomodoro.endDate = nil
        } else {
            let remaining = pomodoro.pausedRemaining ?? duration(for: pomodoro.phase)
            if pomodoro.pausedRemaining == nil { pomodoro.phaseDuration = duration(for: pomodoro.phase) }
            pomodoro.endDate = .now.addingTimeInterval(remaining)
            pomodoro.pausedRemaining = nil
            if pomodoro.phase == .focus, FocusSoundPlayer.shared.autoPlayDuringFocus {
                FocusSoundPlayer.shared.play()
            }
        }
        Haptics.tap(.levelChange)
    }

    func resetPomodoro() {
        pomodoro = PomodoroState(phaseDuration: duration(for: .focus))
        FocusSoundPlayer.shared.stop()
    }

    func skipPomodoroPhase() {
        advancePomodoro(completed: false)
    }

    private func duration(for phase: PomodoroPhase) -> TimeInterval {
        let prefs = Preferences.shared
        switch phase {
        case .focus: return TimeInterval(prefs.pomodoroFocusMinutes * 60)
        case .shortBreak: return TimeInterval(prefs.pomodoroShortBreakMinutes * 60)
        case .longBreak: return TimeInterval(prefs.pomodoroLongBreakMinutes * 60)
        }
    }

    private func advancePomodoro(completed: Bool) {
        let wasRunning = pomodoro.isRunning
        if pomodoro.phase == .focus {
            if completed {
                pomodoro.completedFocusSessions += 1
                focusMinutesToday += Int(pomodoro.phaseDuration / 60)
                UserDefaults.standard.set(focusMinutesToday, forKey: Self.focusKey)
            }
            let cycles = max(2, Preferences.shared.pomodoroCyclesBeforeLongBreak)
            pomodoro.phase = pomodoro.completedFocusSessions > 0 && pomodoro.completedFocusSessions % cycles == 0 ? .longBreak : .shortBreak
            FocusSoundPlayer.shared.stop()
        } else {
            pomodoro.phase = .focus
        }
        pomodoro.phaseDuration = duration(for: pomodoro.phase)
        pomodoro.pausedRemaining = nil
        pomodoro.endDate = wasRunning || completed ? .now.addingTimeInterval(pomodoro.phaseDuration) : nil
        if pomodoro.phase == .focus, pomodoro.endDate != nil, FocusSoundPlayer.shared.autoPlayDuringFocus {
            FocusSoundPlayer.shared.play()
        }
    }

    // MARK: Countdown timers

    func startTimer(minutes: Double, label: String? = nil) {
        let duration = minutes * 60
        let name = label ?? Self.label(for: duration)
        let timer = CountdownTimer(id: UUID(), label: name, duration: duration, endDate: .now.addingTimeInterval(duration))
        withAnimation(IslaMotion.content) { timers.append(timer) }
        Haptics.tap(.levelChange)
    }

    func toggle(_ timer: CountdownTimer) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        if timers[index].isRunning {
            timers[index].pausedRemaining = timers[index].remaining(at: .now)
            timers[index].endDate = nil
        } else {
            timers[index].endDate = .now.addingTimeInterval(timers[index].pausedRemaining ?? timers[index].duration)
            timers[index].pausedRemaining = nil
        }
        Haptics.tap()
    }

    func addMinute(to timer: CountdownTimer) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        timers[index].duration += 60
        if let end = timers[index].endDate { timers[index].endDate = end.addingTimeInterval(60) }
        if let paused = timers[index].pausedRemaining { timers[index].pausedRemaining = paused + 60 }
    }

    func remove(_ timer: CountdownTimer) {
        withAnimation(IslaMotion.content) { timers.removeAll { $0.id == timer.id } }
    }

    // MARK: Stopwatch

    func toggleStopwatch() {
        if let start = stopwatchStart {
            stopwatchAccumulated += Date.now.timeIntervalSince(start)
            stopwatchStart = nil
        } else {
            stopwatchStart = .now
        }
        Haptics.tap()
    }

    func resetStopwatch() {
        stopwatchStart = nil
        stopwatchAccumulated = 0
    }

    // MARK: Completion

    func acknowledgeFinished() {
        alarm?.stop()
        finishedLabel = nil
        LiveActivityCenter.shared.dismissTransient()
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { TimerStore.shared.tick() }
        }
        ticker?.tolerance = 0.1
    }

    private func tick() {
        let now = Date.now
        if pomodoro.isRunning, pomodoro.remaining(at: now) <= 0 {
            let finished = pomodoro.phase
            advancePomodoro(completed: true)
            announce(finished == .focus ? String(localized: "Focus done") : String(localized: "Break over"))
        }
        for timer in timers where timer.isRunning && timer.remaining(at: now) <= 0 {
            timers.removeAll { $0.id == timer.id }
            announce(timer.label)
        }
    }

    private func announce(_ label: String) {
        finishedLabel = label
        Haptics.tap(.levelChange)
        alarm?.stop()
        alarm = NSSound(named: NSSound.Name(Preferences.shared.timerSound)) ?? NSSound(named: "Glass")
        alarm?.play()
        LiveActivityCenter.shared.post(.timerFinished(label: label), duration: 8)
    }

    static func label(for duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60, rest = minutes % 60
            return rest == 0 ? String(localized: "\(hours) h timer") : String(localized: "\(hours) h \(rest) min timer")
        }
        return String(localized: "\(minutes) min timer")
    }
}
