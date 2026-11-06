//
//  TimersView.swift
//  Isla
//

import SwiftUI

struct TimersView: View {
    @Bindable var model: NotchViewModel

    var body: some View {
        HStack(spacing: 12) {
            PomodoroCard()
                .frame(width: 262)
            TimersCard()
                .frame(minWidth: 0, maxWidth: .infinity)
            FocusExtrasCard()
                .frame(width: 156)
        }
    }
}

// MARK: - Pomodoro

struct PomodoroCard: View {
    private let store = TimerStore.shared

    var body: some View {
        IslaCard(padding: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let state = store.pomodoro
                let remaining = state.remaining(at: context.date)
                let progress = 1 - remaining / max(1, state.phaseDuration)
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(state.phase.tint.opacity(0.18), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: max(0.001, progress))
                            .stroke(state.phase.tint.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(remaining.clockString)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                            Text(state.phase.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(state.phase.tint)
                        }
                    }
                    .frame(width: 94, height: 94)

                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Pomodoro").font(.system(size: 13, weight: .bold))
                        } icon: {
                            Image(systemName: state.phase.symbol).foregroundStyle(state.phase.tint)
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<max(2, Preferences.shared.pomodoroCyclesBeforeLongBreak), id: \.self) { index in
                                let cycles = max(2, Preferences.shared.pomodoroCyclesBeforeLongBreak)
                                Circle()
                                    .fill(index < state.completedFocusSessions % cycles || (state.completedFocusSessions > 0 && state.completedFocusSessions % cycles == 0 && state.phase == .longBreak) ? state.phase.tint : Color.white.opacity(0.18))
                                    .frame(width: 7, height: 7)
                            }
                        }
                        Text("\(store.focusMinutesToday) min focused today")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Button { store.togglePomodoro() } label: {
                                Image(systemName: state.isRunning ? "pause.fill" : "play.fill")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(NotchIconButtonStyle(size: 32, prominent: true))
                            Button { store.skipPomodoroPhase() } label: { Image(systemName: "forward.end.fill") }
                                .buttonStyle(NotchIconButtonStyle(size: 28))
                                .help(String(localized: "Skip"))
                            Button { store.resetPomodoro() } label: { Image(systemName: "arrow.counterclockwise") }
                                .buttonStyle(NotchIconButtonStyle(size: 28))
                                .help(String(localized: "Reset"))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Timers

private struct TimersCard: View {
    private let store = TimerStore.shared
    @State private var minutes: Double = 10

    var body: some View {
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    CardHeader(title: "Timers", symbol: "timer", tint: .orange)
                }
                HStack(spacing: 8) {
                    MinuteWheel(minutes: $minutes)
                    Button {
                        store.startTimer(minutes: minutes)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(NotchPillButtonStyle(tint: .orange))
                    Spacer(minLength: 0)
                }
                HStack(spacing: 4) {
                    ForEach([1, 5, 15, 30, 60], id: \.self) { preset in
                        Button(preset >= 60 ? "\(preset / 60)h" : "\(preset)m") {
                            store.startTimer(minutes: Double(preset))
                        }
                        .buttonStyle(NotchPillButtonStyle())
                    }
                }
                if store.timers.isEmpty {
                    Spacer(minLength: 0)
                    Text("Run as many timers as you like. They stay in the notch while they count down.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(store.timers) { timer in
                                TimerRow(timer: timer)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollFade()
                }
            }
        }
    }
}

/// Scroll over the number (or drag) to set minutes, with a haptic tick per step.
private struct MinuteWheel: View {
    @Binding var minutes: Double
    @State private var accumulator: CGFloat = 0
    @State private var dragStart: Double?

    var body: some View {
        HStack(spacing: 2) {
            Button { step(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(NotchIconButtonStyle(size: 22))
            Text("\(Int(minutes))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: minutes))
                .frame(width: 44)
                .overlay(alignment: .bottom) {
                    Text("min").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.secondary).offset(y: 9)
                }
                .gesture(DragGesture()
                    .onChanged { value in
                        if dragStart == nil { dragStart = minutes }
                        let proposed = (dragStart ?? minutes) - Double(value.translation.height / 6)
                        let clamped = min(180, max(1, proposed.rounded()))
                        if clamped != minutes {
                            minutes = clamped
                            Haptics.tap()
                        }
                    }
                    .onEnded { _ in dragStart = nil })
            Button { step(1) } label: { Image(systemName: "plus") }
                .buttonStyle(NotchIconButtonStyle(size: 22))
        }
        .padding(.horizontal, 4)
        .frame(height: 34)
        .background(Capsule().fill(.white.opacity(0.07)))
        .help(String(localized: "Drag up or down to change"))
    }

    private func step(_ delta: Double) {
        let increment: Double = minutes >= 30 ? 5 : 1
        minutes = min(180, max(1, minutes + delta * increment))
        Haptics.tap()
    }
}

private struct TimerRow: View {
    let timer: CountdownTimer
    private let store = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HoverRow(radius: 8) {
                HStack(spacing: 8) {
                    ProgressRing(progress: timer.progress(at: context.date), tint: .orange, lineWidth: 2.5, animated: false)
                        .frame(width: 16, height: 16)
                    Text(timer.label)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(timer.remaining(at: context.date).clockString)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.isRunning ? Color.orange : .secondary)
                    Button { store.addMinute(to: timer) } label: { Image(systemName: "plus") }
                        .buttonStyle(NotchIconButtonStyle(size: 20))
                        .help(String(localized: "Add a minute"))
                    Button { store.toggle(timer) } label: { Image(systemName: timer.isRunning ? "pause.fill" : "play.fill") }
                        .buttonStyle(NotchIconButtonStyle(size: 20))
                    Button { store.remove(timer) } label: { Image(systemName: "xmark") }
                        .buttonStyle(NotchIconButtonStyle(size: 20))
                }
            }
        }
    }
}

// MARK: - Stopwatch & sounds

private struct FocusExtrasCard: View {
    private let store = TimerStore.shared
    @Bindable private var sounds = FocusSoundPlayer.shared

    private func stopwatchLabel(at date: Date) -> some View {
        let elapsed = store.stopwatchElapsed(at: date)
        return Text(String(format: "%@.%d", elapsed.clockString, Int(elapsed * 10) % 10))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
    }

    var body: some View {
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(title: "Stopwatch", symbol: "stopwatch", tint: .yellow)
                // Ticks ten times a second only while it runs; a stopped stopwatch is just text.
                if store.isStopwatchRunning {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        stopwatchLabel(at: context.date)
                    }
                } else {
                    stopwatchLabel(at: .now)
                }
                HStack(spacing: 6) {
                    Button { store.toggleStopwatch() } label: {
                        Image(systemName: store.isStopwatchRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(NotchIconButtonStyle(size: 26, prominent: true))
                    Button { store.resetStopwatch() } label: { Image(systemName: "arrow.counterclockwise") }
                        .buttonStyle(NotchIconButtonStyle(size: 26))
                }
                Divider().overlay(.white.opacity(0.1))
                HStack {
                    Menu {
                        ForEach(FocusSound.allCases) { sound in
                            Button { sounds.sound = sound } label: { Label(sound.title, systemImage: sound.symbol) }
                        }
                        Divider()
                        Toggle("Play during focus", isOn: $sounds.autoPlayDuringFocus)
                    } label: {
                        Label(sounds.sound.title, systemImage: sounds.sound.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    Spacer(minLength: 0)
                    Button { sounds.toggle() } label: {
                        Image(systemName: sounds.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(NotchIconButtonStyle(size: 24))
                }
                Slider(value: $sounds.volume, in: 0...1)
                    .controlSize(.mini)
                    .tint(.white)
            }
        }
    }
}

/// Compact focus widget for the Nook.
struct FocusWidgetCard: View {
    private let store = TimerStore.shared

    var body: some View {
        IslaCard(padding: 11) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let state = store.pomodoro
                let remaining = state.remaining(at: context.date)
                VStack(alignment: .leading, spacing: 6) {
                    CardHeader(title: "Focus", symbol: state.phase.symbol, tint: state.phase.tint)
                    Spacer(minLength: 0)
                    Text(remaining.clockString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    ProgressView(value: 1 - remaining / max(1, state.phaseDuration))
                        .tint(state.phase.tint)
                    HStack {
                        Text(state.phase.title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button { store.togglePomodoro() } label: {
                            Image(systemName: state.isRunning ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(NotchIconButtonStyle(size: 26, prominent: true))
                    }
                }
            }
        }
    }
}
