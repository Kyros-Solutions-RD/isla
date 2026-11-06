//
//  AgentComponents.swift
//  Isla
//
//  Small pieces shared by the AI tab and the notch ears: the tool glyph with
//  its working halo, the thinking dots, the activity sparkline and the state pill.
//

import AppKit
import SwiftUI

// MARK: - Glyph

/// A rounded tile in the tool's colors. Editors and apps use their real icon.
struct AgentGlyph: View {
    let tool: AgentTool
    var icon: NSImage? = nil
    var size: CGFloat = 28
    var working = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let radius = size * 0.3
        ZStack {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(-size * 0.06)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tool.gradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    }
                Image(systemName: tool.symbol)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if working {
                WorkingHalo(tint: tool.tint, radius: radius + 3)
                    .padding(-3)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(IslaMotion.content, value: working)
    }
}

/// A light that travels around the glyph while the agent works, rotated by Core Animation.
private struct WorkingHalo: NSViewRepresentable {
    let tint: Color
    let radius: CGFloat

    func makeNSView(context: Context) -> HaloView { HaloView() }

    func updateNSView(_ view: HaloView, context: Context) {
        view.configure(color: NSColor(tint), radius: radius,
                       animated: !context.environment.accessibilityReduceMotion)
    }
}

final class HaloView: NSView {
    private let gradient = CAGradientLayer()
    private let ring = CAShapeLayer()
    private var color = NSColor.white
    private var radius: CGFloat = 8
    private var animated = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        ring.fillColor = nil
        ring.strokeColor = NSColor.black.cgColor
        ring.lineWidth = 1.6
        layer?.addSublayer(gradient)
        layer?.mask = ring
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(color: NSColor, radius: CGFloat, animated: Bool) {
        self.color = color
        self.radius = radius
        self.animated = animated
        needsLayout = true
    }

    override func layout() {
        super.layout()
        // The ring stays put; only the light inside it turns.
        let side = max(bounds.width, bounds.height) * 1.5
        gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        gradient.colors = [color.withAlphaComponent(0), color.withAlphaComponent(0.15), color, color.withAlphaComponent(0)].map(\.cgColor)
        ring.frame = bounds
        ring.path = CGPath(roundedRect: bounds.insetBy(dx: 0.8, dy: 0.8),
                           cornerWidth: radius, cornerHeight: radius, transform: nil)
        if animated, gradient.animation(forKey: "spin") == nil {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = -2 * Double.pi
            spin.duration = 2.4
            spin.repeatCount = .infinity
            spin.isRemovedOnCompletion = false
            gradient.add(spin, forKey: "spin")
        } else if !animated {
            gradient.removeAnimation(forKey: "spin")
        }
    }
}

/// Up to three glyphs fanned out, for the notch ear.
struct AgentGlyphStack: View {
    let sessions: [AgentSession]
    var size: CGFloat = 17

    var body: some View {
        let shown = Array(sessions.prefix(3))
        HStack(spacing: -size * 0.42) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, session in
                AgentGlyph(tool: session.tool, icon: AgentMonitor.shared.iconForSession(session), size: size)
                    .padding(1.2)
                    .background(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous).fill(.black))
                    .zIndex(Double(shown.count - index))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(IslaMotion.activity, value: shown.map(\.id))
    }
}

// MARK: - Thinking dots

/// Three dots rising and fading in a wave. Core Animation runs the wave in the window
/// server, so it costs almost nothing even when it stays on around the closed notch for
/// hours (a SwiftUI timeline redrawing at 30 fps cost about 12 % of a core).
struct ThinkingDots: NSViewRepresentable {
    var tint: Color = .white
    var dot: CGFloat = 4.5
    var active = true

    func makeNSView(context: Context) -> WaveDotsView {
        let view = WaveDotsView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: WaveDotsView, context: Context) {
        view.configure(color: NSColor(tint), dot: dot,
                       animated: active && !context.environment.accessibilityReduceMotion)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WaveDotsView, context: Context) -> CGSize? {
        CGSize(width: dot * 4.2, height: dot * 1.6)
    }
}

final class WaveDotsView: NSView {
    private var dots: [CALayer] = []
    private var signature = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { false }

    func configure(color: NSColor, dot: CGFloat, animated: Bool) {
        let key = "\(color.description)-\(dot)-\(animated)"
        guard key != signature, let root = layer else { return }
        signature = key
        dots.forEach { $0.removeFromSuperlayer() }
        dots = (0..<3).map { index in
            let layer = CALayer()
            layer.backgroundColor = color.cgColor
            layer.cornerRadius = dot / 2
            layer.frame = CGRect(x: CGFloat(index) * dot * 1.6, y: 0, width: dot, height: dot)
            layer.opacity = animated ? 0.5 : 0.75
            if animated {
                let rise = CAKeyframeAnimation(keyPath: "transform.translation.y")
                rise.values = [0, dot * 0.45, 0]
                let glow = CAKeyframeAnimation(keyPath: "opacity")
                glow.values = [0.5, 1, 0.5]
                let wave = CAAnimationGroup()
                wave.animations = [rise, glow]
                wave.duration = 1.16
                wave.repeatCount = .infinity
                wave.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                // Each dot starts a little later, so the wave travels left to right.
                wave.beginTime = CACurrentMediaTime() + Double(index) * 0.14
                wave.isRemovedOnCompletion = false
                layer.add(wave, forKey: "wave")
            }
            root.addSublayer(layer)
            return layer
        }
    }
}

// MARK: - Sparkline

/// CPU over the last minute. Busy agents draw hills; quiet ones a flat line.
struct ActivitySparkline: View {
    let values: [Double]
    var tint: Color
    var length = 26

    var body: some View {
        let padded = Array(repeating: 0.0, count: max(0, length - values.count)) + values.suffix(length)
        let peak = max(12, padded.max() ?? 0)
        GeometryReader { proxy in
            let size = proxy.size
            let step = size.width / CGFloat(max(1, padded.count - 1))
            let points = padded.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) * step,
                        y: size.height - 1 - (size.height - 2) * CGFloat(min(value, peak) / peak))
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(tint.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
        .animation(.smooth(duration: 0.6), value: values)
    }
}

// MARK: - State pill

struct AgentStatePill: View {
    let state: AgentState

    var body: some View {
        HStack(spacing: 4) {
            if state == .working {
                ThinkingDots(tint: state.tint, dot: 3.4)
                    .transition(.blurReplace)
            } else {
                Image(systemName: state.symbol)
                    .font(.system(size: 8.5, weight: .bold))
                    .symbolEffect(.wiggle, value: state == .needsYou)
                    .transition(.blurReplace)
            }
            Text(state.title)
                .contentTransition(.interpolate)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(state.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(state.tint.opacity(0.14)))
        .fixedSize()
        .animation(IslaMotion.snappy, value: state)
    }
}

// MARK: - Durations

enum AgentDuration {
    /// "12 min", "1 h 5 min", in the user's language.
    static func label(since start: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(start))
        if seconds < 60 { return String(localized: "just now") }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? ""
    }

    /// 300 → "5 h", 10080 → "7 d".
    static func window(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)m"
    }
}

extension AgentMonitor {
    /// The icon to show for a session: the editor's own icon, otherwise none (the glyph is drawn).
    func iconForSession(_ session: AgentSession) -> NSImage? {
        session.tool.kind == .editor ? icon(bundleID: session.hostBundleID) : nil
    }
}

// MARK: - Notch ears

/// Left ear while agents work: their glyphs and what they work on.
struct AgentsEarLeading: View {
    private let monitor = AgentMonitor.shared

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: monitor.activeSessions
                .map { "\($0.project ?? $0.tool.name), \($0.state.titleString)" }
                .joined(separator: "; ")))
    }

    @ViewBuilder private var content: some View {
        let active = monitor.activeSessions
        let working = active.filter { $0.state == .working }
        HStack(spacing: 6) {
            AgentGlyphStack(sessions: active, size: 17)
            Group {
                if working.count > 1 && active.count == working.count {
                    Text("\(working.count) working")
                } else if let first = active.first {
                    Text(verbatim: first.project ?? first.tool.name)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .contentTransition(.opacity)
        }
        .animation(IslaMotion.content, value: active.map(\.id))
    }
}

struct AgentsEarTrailing: View {
    private let monitor = AgentMonitor.shared

    var body: some View {
        let waitsOnYou = monitor.activeSessions.first?.state == .needsYou
        ZStack {
            if waitsOnYou {
                // An agent stopped to ask something: a hand that waves until it is answered.
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AgentState.needsYou.tint)
                    // One wave when it appears; the color keeps saying it after that, at no cost.
                    .symbolEffect(.wiggle, value: waitsOnYou)
                    .transition(.blurReplace)
            } else {
                ThinkingDots(tint: monitor.workingSessions.first?.tool.tint ?? .white, dot: 4.2)
                    .transition(.blurReplace)
            }
        }
        .animation(IslaMotion.content, value: waitsOnYou)
    }
}

/// The moment an agent stops: done, or waiting for an answer.
struct AgentFinishedEarLeading: View {
    let toolID: String
    let title: String
    let needsYou: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let tool = AgentCatalog.tool(id: toolID) {
                AgentGlyph(tool: tool, size: 17)
            }
            Text(verbatim: title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
    }
}

struct AgentFinishedEarTrailing: View {
    let needsYou: Bool
    @State private var shown = false

    var body: some View {
        let tint = needsYou ? AgentState.needsYou.tint : AgentState.working.tint
        HStack(spacing: 4) {
            Image(systemName: needsYou ? "hand.raised.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .symbolEffect(.bounce, value: shown)
            Text(needsYou ? "Needs you" : "Done")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .fixedSize()
        .onAppear { shown = true }
    }
}
