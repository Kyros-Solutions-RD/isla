//
//  LiveActivityViews.swift
//  Isla
//
//  Content that lives in the "ears" on both sides of the camera housing.
//

import AppKit
import SwiftUI

extension EnvironmentValues {
    /// The ears are in their compact form: glyphs and signals only, no words.
    @Entry var compactEars = false
}

struct ClosedActivityView: View {
    let activity: LiveActivity
    let model: NotchViewModel

    var body: some View {
        if let notification = activity.kind.notification {
            NotificationIslandContent(notification: notification, model: model)
        } else if case .call(let call) = activity.kind {
            IncomingCallIsland(call: call, model: model)
        } else {
            ears
        }
    }

    @ViewBuilder private var ears: some View {
        let notch = model.notchSize
        let compact = model.showsCompactEars
        let earWidth = model.earWidth(for: activity.kind, compact: compact)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Both ears slide out of the camera housing toward their side.
                leading
                    .frame(width: earWidth - 12, alignment: .leading)
                    .padding(.leading, 12)
                    .emerge(delay: 0.05, offset: CGSize(width: 16, height: 0))
                Color.clear.frame(width: notch.width)
                trailing
                    .frame(width: earWidth - 12, alignment: .trailing)
                    .padding(.trailing, 12)
                    .emerge(delay: 0.05, offset: CGSize(width: -16, height: 0))
            }
            .frame(height: notch.height)
            .environment(\.compactEars, compact)
            .animation(IslaMotion.activity, value: compact)

            if model.showsMiniPlayer {
                IslandMiniPlayer()
                    .frame(height: NotchViewModel.miniPlayerHeight)
                    .padding(.horizontal, 14)
                    .transition(.miniPlayer)
            } else if activity.kind.detailHeight > 0 {
                detail
                    .frame(height: activity.kind.detailHeight)
                    .padding(.horizontal, 16)
                    .emerge(delay: 0.1, offset: CGSize(width: 0, height: -6))
            } else if model.showsIslandLyrics, let info = NowPlayingService.shared.info {
                IslandLyricLine(info: info)
                    .frame(height: 26)
                    .padding(.horizontal, 18)
                    .emerge(delay: 0.1, offset: CGSize(width: 0, height: -6))
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
                if !model.showsCompactEars {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .transition(.compactEarText)
                }
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
                if !model.showsCompactEars {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .transition(.compactEarText)
                }
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
        case .agents:
            AgentsEarLeading()
        case .agentFinished(let toolID, let title, let needsYou):
            AgentFinishedEarLeading(toolID: toolID, title: title, needsYou: needsYou)
        case .systemStats:
            SystemEarLeading()
        case .notification, .call:
            EmptyView()
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
                // The spinning ring on the other side already says it is working.
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
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
        case .agents:
            AgentsEarTrailing()
        case .agentFinished(_, _, let needsYou):
            AgentFinishedEarTrailing(needsYou: needsYou)
        case .systemStats:
            SystemEarTrailing()
        case .notification, .call:
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
        case .agents, .agentFinished:
            model.controller?.open(.agents)
        case .systemStats:
            QuickActions.shared.openActivityMonitor()
        default:
            model.controller?.open()
        }
    }
}

/// The song and its buttons, out under the camera while the pointer rests on the island.
struct IslandMiniPlayer: View {
    private let media = NowPlayingService.shared

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                MarqueeText(text: media.info?.title ?? "", font: .system(size: 11.5, weight: .semibold), speed: 24)
                Text(media.info?.artist ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TransportControls(size: 0.64)
                .fixedSize()
        }
        .padding(.bottom, 4)
    }
}

extension AnyTransition {
    /// The small player drops out from under the camera as the island grows, and folds
    /// back up quickly when the pointer leaves.
    static let miniPlayer = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .offset(y: -8)).combined(with: AnyTransition(.blurReplace))
            .animation(IslaMotion.emerge.delay(0.05)),
        removal: .opacity.combined(with: .offset(y: -4)).animation(.easeIn(duration: 0.1)))

    /// Words in an ear slide in from the camera side as the ear opens up, and slip back into
    /// it when the ear settles to its compact form.
    static let compactEarText = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .offset(x: -8)).combined(with: AnyTransition(.blurReplace))
            .animation(IslaMotion.content.delay(0.06)),
        removal: .opacity.combined(with: AnyTransition(.blurReplace)).animation(.easeIn(duration: 0.12)))
}

// MARK: - Second activity

/// A small bubble hanging beside the island for the second thing going on: the cover of
/// the song, the agent at work, a timer or a download. A click opens its tab.
struct SecondaryBubble: View {
    let activity: LiveActivity
    let model: NotchViewModel
    let side: CGFloat
    @State private var hovering = false

    var body: some View {
        ZStack {
            NotchShape(topRadius: 5, bottomRadius: side * 0.42)
                .fill(Color.black)
            content
                .frame(width: side * 0.62, height: side * 0.62)
                .padding(.top, 1)
        }
        .frame(width: side + 10, height: side)
        .scaleEffect(hovering ? 1.08 : 1, anchor: .top)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { open() }
        .animation(IslaMotion.snappy, value: hovering)
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(label))
        .accessibilityAction { open() }
    }

    @ViewBuilder private var content: some View {
        switch activity.kind {
        case .nowPlaying, .trackChanged:
            ArtworkThumbnail(size: side * 0.62, radius: side * 0.31)
        case .agents:
            if let session = AgentMonitor.shared.activeSessions.first {
                AgentGlyph(tool: session.tool, size: side * 0.56, working: session.state == .working)
            }
        case .timer:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let primary = TimerStore.shared.primaryDisplay(at: context.date)
                ProgressRing(progress: primary?.progress ?? 0, tint: primary?.tint ?? .orange, lineWidth: 2.4, animated: false)
            }
        case .download(_, let progress):
            ProgressRing(progress: progress ?? 0.12, indeterminate: progress == nil, tint: .blue, lineWidth: 2.4)
        case .meeting:
            Image(systemName: "video.fill")
                .font(.system(size: side * 0.32, weight: .bold))
                .foregroundStyle(.green)
        case .systemStats:
            SystemBubbleRing()
        default:
            EmptyView()
        }
    }

    private var label: LocalizedStringKey {
        switch activity.kind {
        case .nowPlaying, .trackChanged: "Now Playing"
        case .agents: "AI Agents"
        case .timer: "Focus"
        case .download: "Downloads"
        case .meeting: "Upcoming meetings"
        case .systemStats: "System"
        default: "Open Nook"
        }
    }

    private func open() {
        Haptics.tap()
        switch activity.kind {
        case .agents: model.controller?.open(.agents, makeKey: true)
        case .timer: model.controller?.open(.timers, makeKey: true)
        case .meeting: model.controller?.open(.calendar, makeKey: true)
        case .systemStats: QuickActions.shared.openActivityMonitor()
        default: model.controller?.open(.home, makeKey: true)
        }
    }
}

/// The bubble comes out of the island's side: it starts tucked against the island,
/// small and soft, and slides out to its place.
struct BubbleSplit: ViewModifier {
    var progress: Double
    var distance: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: -distance * (1 - progress))
            .scaleEffect(0.35 + 0.65 * progress, anchor: .leading)
            .blur(radius: 5 * (1 - progress))
            .opacity(progress)
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
    /// Rings that tick every second (timers) move too little to animate; skipping the
    /// animation keeps the closed notch idle between ticks.
    var animated = true

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: lineWidth)
            if indeterminate {
                SpinningArc(tint: tint, lineWidth: lineWidth)
            } else {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(animated ? .smooth : nil, value: progress)
    }
}

/// The arc of a ring that waits for an unknown amount of time, turned by Core Animation.
private struct SpinningArc: NSViewRepresentable {
    var tint: Color
    var lineWidth: CGFloat

    func makeNSView(context: Context) -> SpinningArcView { SpinningArcView() }

    func updateNSView(_ view: SpinningArcView, context: Context) {
        view.configure(color: NSColor(tint), lineWidth: lineWidth,
                       animated: !context.environment.accessibilityReduceMotion)
    }
}

final class SpinningArcView: NSView {
    private let arc = CAShapeLayer()
    private var animated = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        arc.fillColor = nil
        arc.lineCap = .round
        arc.strokeEnd = 0.28
        layer?.addSublayer(arc)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(color: NSColor, lineWidth: CGFloat, animated: Bool) {
        arc.strokeColor = color.cgColor
        arc.lineWidth = lineWidth
        self.animated = animated
        needsLayout = true
    }

    override func layout() {
        super.layout()
        arc.frame = bounds
        let inset = arc.lineWidth / 2
        arc.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
        if animated, arc.animation(forKey: "spin") == nil {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = -2 * Double.pi
            spin.duration = 1
            spin.repeatCount = .infinity
            spin.isRemovedOnCompletion = false
            arc.add(spin, forKey: "spin")
        } else if !animated {
            arc.removeAnimation(forKey: "spin")
        }
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
/// Core Animation plays the motion in the window server: a SwiftUI timeline redrawing
/// the bars 24 times a second kept a core about 10 % busy for as long as music played.
struct AudioBars: NSViewRepresentable {
    var isPlaying: Bool
    var tint: Color = .white
    var barCount = 4

    func makeNSView(context: Context) -> EqualizerView { EqualizerView() }

    func updateNSView(_ view: EqualizerView, context: Context) {
        view.configure(color: NSColor(tint), bars: barCount,
                       playing: isPlaying && !context.environment.accessibilityReduceMotion)
    }
}

final class EqualizerView: NSView {
    private var bars: [CALayer] = []
    private var color = NSColor.white
    private var playing = false
    private var count = 4

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(color: NSColor, bars count: Int, playing: Bool) {
        guard color != self.color || count != self.count || playing != self.playing || bars.isEmpty else { return }
        self.color = color
        self.count = count
        self.playing = playing
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let root = layer, bounds.width > 0 else { return }
        if bars.count != count {
            bars.forEach { $0.removeFromSuperlayer() }
            bars = (0..<count).map { _ in
                let bar = CALayer()
                root.addSublayer(bar)
                return bar
            }
        }
        let spacing = bounds.width * 0.12
        let width = (bounds.width - spacing * CGFloat(count - 1)) / CGFloat(count)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        for (index, bar) in bars.enumerated() {
            bar.backgroundColor = color.cgColor
            bar.cornerRadius = width / 2
            bar.position = CGPoint(x: CGFloat(index) * (width + spacing) + width / 2, y: bounds.midY)
            bar.bounds = CGRect(x: 0, y: 0, width: width, height: max(2, bounds.height * 0.18))
            if playing {
                if bar.animation(forKey: "level") == nil { bar.add(levelAnimation(for: index), forKey: "level") }
            } else {
                bar.removeAnimation(forKey: "level")
            }
        }
        CATransaction.commit()
    }

    /// The same blend of a fast wave and a slow wobble the bars always had, sampled into keyframes.
    private func levelAnimation(for index: Int) -> CAAnimation {
        let phase = Double(index) * 1.7
        let fast = 5.2 + Double(index) * 1.3
        let duration = 2 * Double.pi / 2.3 * 2 // a whole wobble cycle, so the loop is seamless
        let steps = 48
        let values: [CGFloat] = (0...steps).map { step in
            let t = duration * Double(step) / Double(steps)
            let wave = (sin(t * fast + phase) + 1) / 2
            let wobble = (sin(t * 2.3 + phase * 2) + 1) / 2
            return max(2, bounds.height * CGFloat(0.22 + 0.78 * (wave * 0.7 + wobble * 0.3)))
        }
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
        animation.values = values
        animation.duration = duration
        animation.calculationMode = .cubic
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        return animation
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
    /// Compact, only the ring stays by the camera; the name shows when the phase changes.
    @Environment(\.compactEars) private var compact

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let primary = timers.primaryDisplay(at: context.date)
            HStack(spacing: 6) {
                ProgressRing(progress: primary?.progress ?? 0, tint: primary?.tint ?? .orange, lineWidth: 2.4, animated: false)
                    .frame(width: 15, height: 15)
                if !compact {
                    Text(primary?.label ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.85))
                        .transition(.compactEarText)
                }
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
                .lineLimit(1)
                // Over an hour, the compact ear shrinks the figures a little instead of cutting them.
                .minimumScaleFactor(0.75)
                .foregroundStyle(primary?.tint ?? .orange)
                .contentTransition(.numericText(countsDown: true))
        }
    }
}

/// The current lyric line, shown under the island while music plays.
struct IslandLyricLine: View {
    let info: NowPlayingInfo
    private let lyrics = LyricsService.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let line = lyrics.line(at: info.elapsed(at: context.date))
            Text(line?.text.nonEmpty ?? "♪")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NowPlayingService.shared.accentColor ?? .white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.3), value: line?.id)
        }
    }
}
