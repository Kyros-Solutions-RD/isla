//
//  AgentComponents.swift
//  Isla
//
//  Small pieces shared by the AI tab and the notch ears: the tool glyph with
//  its working halo, the thinking dots, the activity sparkline and the state pill.
//

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
                    .symbolEffect(.breathe, options: .repeating, isActive: working && !reduceMotion)
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

/// A light that travels around the glyph while the agent works.
private struct WorkingHalo: View {
    let tint: Color
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let angle = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4 * 360
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    AngularGradient(colors: [tint.opacity(0), tint.opacity(0.15), tint, tint.opacity(0)],
                                    center: .center, angle: .degrees(angle)),
                    lineWidth: 1.6)
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

struct ThinkingDots: View {
    var tint: Color = .white
    var dot: CGFloat = 4.5
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: dot * 0.6) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = active && !reduceMotion ? (sin(t * 5.4 - Double(index) * 0.75) + 1) / 2 : 0.5
                    Circle()
                        .fill(tint)
                        .frame(width: dot, height: dot)
                        .opacity(0.5 + 0.5 * wave)
                        .offset(y: -dot * 0.45 * wave)
                }
            }
            .frame(height: dot * 1.6, alignment: .bottom)
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
                    .symbolEffect(.wiggle, options: .repeating)
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
