//
//  SystemStatsViews.swift
//  Isla
//
//  The System widget in the Nook and the optional ears around the closed notch. The
//  graphs morph from one reading to the next instead of jumping.
//

import AppKit
import SwiftUI

// MARK: - Widget

struct SystemWidgetCard: View {
    let model: NotchViewModel
    private let stats = SystemStats.shared

    var body: some View {
        IslaCard {
            VStack(alignment: .leading, spacing: 9) {
                CardHeader(title: "System", symbol: "cpu", tint: .green) {
                    if stats.thermal != .nominal {
                        ThermalBadge(state: stats.thermal)
                    }
                }
                StatLine(label: "CPU", value: Self.percent(stats.cpu), tint: Self.cpuTint(stats.cpu)) {
                    Sparkline(series: AnimatableSeries(stats.cpuHistory), ceiling: 1, tint: Self.cpuTint(stats.cpu))
                }
                StatLine(label: "Memory", value: "\(SystemStats.bytes(Int64(stats.memoryUsed))) / \(SystemStats.bytes(Int64(stats.memoryTotal)))",
                         tint: stats.memoryFraction > 0.85 ? .orange : .blue) {
                    MeterBar(fraction: stats.memoryFraction, tint: stats.memoryFraction > 0.85 ? .orange : .blue)
                }
                StatLine(label: "Network", value: "↓ \(SystemStats.rate(stats.download))  ↑ \(SystemStats.rate(stats.upload))", tint: .teal) {
                    Sparkline(series: AnimatableSeries(stats.downloadHistory),
                              ceiling: max(60_000, stats.downloadHistory.max() ?? 0) * 1.15, tint: .teal)
                }
                StatLine(label: "Disk", value: String(localized: "\(SystemStats.bytes(stats.diskFree)) free"), tint: .purple) {
                    MeterBar(fraction: stats.diskUsedFraction, tint: stats.diskUsedFraction > 0.9 ? .red : .purple)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { QuickActions.shared.openActivityMonitor() }
        .help(String(localized: "Open Activity Monitor"))
        .onAppear { stats.watch("widget") }
        .onDisappear { stats.unwatch("widget") }
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func cpuTint(_ value: Double) -> Color {
        value > 0.85 ? .red : (value > 0.6 ? .orange : .green)
    }
}

/// A label and its value on one line, with a graph or a bar under it.
private struct StatLine<Graph: View>: View {
    let label: LocalizedStringKey
    let value: String
    let tint: Color
    @ViewBuilder var graph: Graph

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 4)
                Text(verbatim: value)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    // No rolling digits: they blur on every reading, and readings never stop.
            }
            graph
                .frame(height: 9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: value))
    }
}

struct MeterBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.09))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(4, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 5)
        .frame(maxHeight: .infinity, alignment: .center)
        // No animation: it would run a SwiftUI layout pass per frame every couple of seconds.
    }
}

private struct ThermalBadge: View {
    let state: ProcessInfo.ThermalState

    var body: some View {
        Label(state == .critical ? "Hot" : "Warm", systemImage: "thermometer.medium")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(state == .fair ? Color.yellow : (state == .serious ? .orange : .red))
            .labelStyle(.titleAndIcon)
    }
}

// MARK: - Sparkline

/// The readings a graph shows, oldest first.
struct AnimatableSeries: Equatable {
    var values: [Double]

    init(_ values: [Double]) { self.values = values }
}

/// A small line graph. Drawn and animated by Core Animation: the path morphs on the GPU
/// between readings, so a graph that changes every second costs next to nothing (the
/// SwiftUI version redrew a gradient-filled path on the CPU on every frame).
struct Sparkline: NSViewRepresentable {
    let series: AnimatableSeries
    let ceiling: Double
    let tint: Color
    /// Morph between readings. Off around the closed notch, where it would never rest.
    var animated = true

    func makeNSView(context: Context) -> SparklineView { SparklineView() }

    func updateNSView(_ view: SparklineView, context: Context) {
        let values = series.values.map { ceiling > 0 ? min(1, max(0, $0 / ceiling)) : 0 }
        view.update(values: values, color: NSColor(tint), animated: animated)
    }
}

final class SparklineView: NSView {
    private let line = CAShapeLayer()
    private let area = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private var values: [Double] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        line.fillColor = nil
        line.lineWidth = 1.4
        line.lineCap = .round
        line.lineJoin = .round
        gradient.mask = area
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(gradient)
        layer?.addSublayer(line)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        line.frame = bounds
        area.frame = bounds
        gradient.frame = bounds
        line.path = path(closed: false)
        area.path = path(closed: true)
        CATransaction.commit()
    }

    func update(values next: [Double], color: NSColor, animated: Bool) {
        line.strokeColor = color.cgColor
        gradient.colors = [color.withAlphaComponent(0.32).cgColor, color.withAlphaComponent(0).cgColor]
        let morph = animated && values.count == next.count && !bounds.isEmpty
        values = next
        let newLine = path(closed: false), newArea = path(closed: true)
        if morph {
            for (layer, path) in [(line, newLine), (area, newArea)] {
                let animation = CABasicAnimation(keyPath: "path")
                animation.fromValue = layer.presentation()?.path ?? layer.path
                animation.toValue = path
                animation.duration = 0.4
                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(animation, forKey: "morph")
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        line.path = newLine
        area.path = newArea
        CATransaction.commit()
    }

    /// A gentle curve through the readings (y grows upward in AppKit layers).
    private func path(closed: Bool) -> CGPath {
        let path = CGMutablePath()
        guard values.count > 1, bounds.width > 0 else { return path }
        let rect = bounds.insetBy(dx: 0, dy: 1)
        let step = rect.width / CGFloat(values.count - 1)
        func point(_ index: Int) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.minY + CGFloat(values[index]) * rect.height)
        }
        path.move(to: point(0))
        for index in 1..<values.count {
            let previous = point(index - 1), current = point(index)
            path.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2), control: previous)
            if index == values.count - 1 { path.addLine(to: current) }
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: bounds.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: bounds.minY))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Ears

/// Left ear: the processor's load.
struct SystemEarLeading: View {
    private let stats = SystemStats.shared

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "cpu")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SystemWidgetCard.cpuTint(stats.cpu))
            // Around the closed notch nothing animates: it would never come to rest.
            Text(verbatim: SystemWidgetCard.percent(stats.cpu))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Sparkline(series: AnimatableSeries(Array(stats.cpuHistory.suffix(16))), ceiling: 1,
                      tint: SystemWidgetCard.cpuTint(stats.cpu), animated: false)
                .frame(width: 26, height: 11)
        }
        .lineLimit(1)
        .onAppear { stats.watch("ears") }
        .onDisappear { stats.unwatch("ears") }
    }
}

/// Right ear: what is coming in over the network.
struct SystemEarTrailing: View {
    private let stats = SystemStats.shared

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.down")
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.teal)
            Text(verbatim: SystemStats.rate(stats.download))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// The processor's load as a ring, for the bubble beside the island.
struct SystemBubbleRing: View {
    private let stats = SystemStats.shared

    var body: some View {
        ProgressRing(progress: stats.cpu, tint: SystemWidgetCard.cpuTint(stats.cpu), lineWidth: 2.4, animated: false)
            .onAppear { stats.watch("bubble") }
            .onDisappear { stats.unwatch("bubble") }
    }
}
