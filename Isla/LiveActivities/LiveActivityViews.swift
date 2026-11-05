//
//  LiveActivityViews.swift
//  Isla
//
//  Content that lives in the "ears" on both sides of the camera housing.
//

import SwiftUI

struct ClosedActivityView: View {
    let activity: LiveActivity
    let model: NotchViewModel

    var body: some View {
        let notch = model.notchSize
        let ears = activity.kind.earWidths(notchHeight: notch.height)
        let earWidth = max(ears.left, ears.right)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .frame(width: earWidth - 12, alignment: .leading)
                    .padding(.leading, 12)
                Color.clear.frame(width: notch.width)
                trailing
                    .frame(width: earWidth - 12, alignment: .trailing)
                    .padding(.trailing, 12)
            }
            .frame(height: notch.height)

            if activity.kind.detailHeight > 0 {
                detail
                    .frame(height: activity.kind.detailHeight)
                    .padding(.horizontal, 16)
            }
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
    }

    // MARK: Leading ear

    @ViewBuilder private var leading: some View {
        switch activity.kind {
        case .nowPlaying, .trackChanged:
            ArtworkThumbnail(size: model.notchSize.height - 10, radius: 6)
        case .power(let level, let charging, let plugged):
            HStack(spacing: 5) {
                Image(systemName: charging ? "bolt.fill" : (plugged ? "powerplug.fill" : "battery.100percent"))
                    .foregroundStyle(charging ? Color.green : .white)
                    .font(.system(size: 12, weight: .bold))
                    .symbolEffect(.bounce, value: level)
                Text(charging ? "Charging" : (plugged ? "Plugged In" : "On Battery"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
        case .lowBattery:
            HStack(spacing: 5) {
                Image(systemName: "battery.25percent")
                    .foregroundStyle(.red)
                    .font(.system(size: 13, weight: .bold))
                Text("Low Battery")
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
        case .device(let name, let device, let connected, _):
            HStack(spacing: 6) {
                Image(systemName: device.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .symbolEffect(.bounce, value: connected)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(connected ? "Connected" : "Disconnected")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        case .hud(let kind, let value, let muted):
            Image(systemName: kind.symbol(for: value, muted: muted))
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
        case .timer:
            TimerEarLeading()
        case .timerFinished(let label):
            HStack(spacing: 5) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.wiggle, options: .repeating)
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
        case .download(let name, let progress):
            HStack(spacing: 6) {
                ProgressRing(progress: progress ?? 0.12, indeterminate: progress == nil, tint: .blue)
                    .frame(width: 15, height: 15)
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .downloadFinished(let name, _):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13, weight: .bold))
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .meeting(let title, _, _):
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
        case .capsLock(let on):
            HStack(spacing: 6) {
                Image(systemName: on ? "capslock.fill" : "capslock")
                    .font(.system(size: 12, weight: .bold))
                Text("Caps Lock")
                    .font(.system(size: 11.5, weight: .semibold))
            }
        case .shelf:
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text("On Shelf")
                    .font(.system(size: 11.5, weight: .semibold))
            }
        case .message(let symbol, let title):
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
        }
    }

    // MARK: Trailing ear

    @ViewBuilder private var trailing: some View {
        switch activity.kind {
        case .nowPlaying, .trackChanged:
            AudioBars(isPlaying: NowPlayingService.shared.isPlaying,
                      tint: NowPlayingService.shared.accentColor ?? .white)
                .frame(width: 20, height: 14)
        case .power(let level, let charging, _):
            HStack(spacing: 5) {
                Text("\(level)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                BatteryGlyph(level: level, charging: charging, width: 24)
            }
        case .lowBattery(let level):
            Text("\(level)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
        case .device(_, _, let connected, let battery):
            if let battery, connected {
                HStack(spacing: 4) {
                    Text("\(battery)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    ProgressRing(progress: Double(battery) / 100, tint: battery <= 20 ? .red : .green)
                        .frame(width: 14, height: 14)
                }
            } else {
                Image(systemName: connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(connected ? Color.green : .secondary)
                    .font(.system(size: 13, weight: .semibold))
            }
        case .hud(_, let value, let muted):
            Text(muted ? "—" : "\(Int((value * 100).rounded()))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
        case .timer:
            TimerEarTrailing()
        case .timerFinished:
            Button("Stop") { TimerStore.shared.acknowledgeFinished() }
                .buttonStyle(NotchPillButtonStyle(tint: .orange))
        case .download(_, let progress):
            if let progress {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
            }
        case .downloadFinished:
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        case .meeting(_, let start, _):
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(MeetingCountdown.label(until: start, now: context.date))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
        case .capsLock(let on):
            Circle()
                .fill(on ? Color.green : Color.white.opacity(0.25))
                .frame(width: 7, height: 7)
        case .shelf(let count):
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        case .message:
            EmptyView()
        }
    }

    // MARK: Detail row

    @ViewBuilder private var detail: some View {
        switch activity.kind {
        case .trackChanged:
            let info = NowPlayingService.shared.info
            VStack(spacing: 1) {
                MarqueeText(text: info?.title ?? "", font: .system(size: 12.5, weight: .semibold))
                Text(info?.artist ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 6)
        case .hud(_, let value, let muted):
            HUDBar(value: muted ? 0 : value)
                .frame(height: 5)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
        default:
            EmptyView()
        }
    }

    private func handleTap() {
        switch activity.kind {
        case .meeting(_, _, let url):
            if let url { NSWorkspace.shared.open(url) } else { model.controller?.open(.calendar) }
        case .downloadFinished(_, let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .timer, .timerFinished:
            model.controller?.open(.timers)
        case .shelf:
            model.controller?.open(.shelf)
        default:
            model.controller?.open()
        }
    }
}

enum MeetingCountdown {
    static func label(until start: Date, now: Date) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds <= 30 { return String(localized: "Now") }
        let minutes = Int((seconds / 60).rounded(.up))
        return String(localized: "in \(minutes)m")
    }
}

// MARK: - Building blocks

struct HUDBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(.white)
                    .frame(width: max(5, proxy.size.width * value))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: value)
    }
}

struct ProgressRing: View {
    var progress: Double
    var indeterminate = false
    var tint: Color = .white
    var lineWidth: CGFloat = 2.2

    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: indeterminate ? 0.28 : max(0.02, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .rotationEffect(.degrees(indeterminate && spin ? 360 : 0))
        }
        .animation(indeterminate ? .linear(duration: 1).repeatForever(autoreverses: false) : .smooth, value: spin)
        .animation(.smooth, value: progress)
        .onAppear { if indeterminate { spin = true } }
    }
}

struct BatteryGlyph: View {
    let level: Int
    var charging = false
    var width: CGFloat = 24

    var body: some View {
        let height = width * 0.48
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                    .fill(fill)
                    .frame(width: max(2, (width - 4) * CGFloat(level) / 100))
                    .padding(2)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.45))
                .frame(width: 1.5, height: height * 0.38)
        }
    }

    private var fill: Color {
        if charging { return .green }
        if level <= 10 { return .red }
        if level <= 20 { return .orange }
        return .white
    }
}

/// Lively equalizer bars. They breathe while music plays and rest when paused.
struct AudioBars: View {
    var isPlaying: Bool
    var tint: Color = .white
    var barCount = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: proxy.size.width * 0.12) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let phase = Double(index) * 1.7
                        let wave = (sin(t * (5.2 + Double(index) * 1.3) + phase) + 1) / 2
                        let wobble = (sin(t * 2.3 + phase * 2) + 1) / 2
                        let level = isPlaying ? 0.22 + 0.78 * (wave * 0.7 + wobble * 0.3) : 0.18
                        Capsule()
                            .fill(tint.gradient)
                            .frame(height: max(2, proxy.size.height * level))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .animation(.smooth(duration: 0.3), value: isPlaying)
    }
}

struct ArtworkThumbnail: View {
    var size: CGFloat
    var radius: CGFloat = 6
    private let media = NowPlayingService.shared

    var body: some View {
        Group {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let icon = media.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
            } else {
                ZStack {
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct TimerEarLeading: View {
    private let timers = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let primary = timers.primaryDisplay(at: context.date)
            HStack(spacing: 6) {
                ProgressRing(progress: primary?.progress ?? 0, tint: primary?.tint ?? .orange, lineWidth: 2.4)
                    .frame(width: 15, height: 15)
                Text(primary?.label ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

struct TimerEarTrailing: View {
    private let timers = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let primary = timers.primaryDisplay(at: context.date)
            Text(primary?.remaining.clockString ?? "")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primary?.tint ?? .orange)
                .contentTransition(.numericText(countsDown: true))
        }
    }
}
