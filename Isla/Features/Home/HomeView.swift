//
//  HomeView.swift
//  Isla
//
//  The Nook: a row of widgets the user picks and orders in Settings.
//

import SwiftUI

struct HomeView: View {
    @Bindable var model: NotchViewModel
    private let prefs = Preferences.shared

    var body: some View {
        let widgets = prefs.homeWidgets.isEmpty ? [HomeWidget.media] : prefs.homeWidgets
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let totalSpan = widgets.reduce(0) { $0 + $1.span }
            let unit = (proxy.size.width - spacing * CGFloat(widgets.count - 1)) / max(1, totalSpan)
            HStack(spacing: spacing) {
                ForEach(Array(widgets.enumerated()), id: \.element) { index, widget in
                    widgetView(widget)
                        .frame(width: unit * widget.span)
                        // Cards come out of the notch one after another, left to right.
                        .emerge(delay: 0.06 + Double(index) * 0.05)
                }
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ widget: HomeWidget) -> some View {
        switch widget {
        case .media: NowPlayingCard()
        case .calendar: UpNextCard()
        case .weather: WeatherCard()
        case .timer: FocusWidgetCard()
        case .battery: DevicesCard()
        case .shortcuts: ShortcutsCard()
        case .shelf: ShelfPreviewCard(model: model)
        case .note: QuickNoteCard()
        case .actions: QuickActionsCard(model: model)
        case .agents: AgentsWidgetCard(model: model)
        case .notifications: NotificationsWidgetCard(model: model)
        case .system: SystemWidgetCard(model: model)
        }
    }
}

struct DevicesCard: View {
    private let battery = BatteryMonitor.shared
    private let bluetooth = BluetoothMonitor.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(title: "Battery", symbol: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent", tint: .green) {
                    if battery.isLowPowerMode {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow)
                            .help(String(localized: "Low Power Mode"))
                    }
                }
                if battery.hasBattery {
                    // The Mac's own battery, large: the figure, a bar and what it is doing.
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(battery.level)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(battery.level)))
                        Text(verbatim: "%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(IslaInk.secondary)
                        Spacer(minLength: 4)
                        BatteryGlyph(level: battery.level, charging: battery.isCharging || battery.isPluggedIn, width: 30)
                    }
                    .animation(IslaMotion.snappy, value: battery.level)
                    // VoiceOver reads the figure and the state once, as one sentence.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(battery.level)% · \(battery.statusDescription)"))
                    MeterBar(fraction: Double(battery.level) / 100, tint: levelTint)
                        .frame(height: 6)
                        .accessibilityHidden(true)
                    Label {
                        Text(verbatim: battery.statusDescription)
                    } icon: {
                        Image(systemName: battery.isCharging ? "bolt.fill" : (battery.isPluggedIn ? "powerplug.fill" : "clock"))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IslaInk.secondary)
                    .lineLimit(1)
                    .accessibilityHidden(true)
                }
                ForEach(bluetooth.connected.prefix(battery.hasBattery ? 2 : 4)) { device in
                    HStack(spacing: 8) {
                        Image(systemName: device.kind.symbol).font(.system(size: 13)).frame(width: 20)
                        Text(device.name).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                        Spacer()
                        if let level = device.battery {
                            Text("\(level)%").font(.system(size: 11.5, weight: .semibold, design: .rounded)).monospacedDigit()
                            BatteryGlyph(level: level, width: 20)
                        }
                    }
                }
                if !battery.hasBattery && bluetooth.connected.isEmpty {
                    Text("No devices connected")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var levelTint: Color {
        if battery.level <= 10 && !battery.isCharging { return .red }
        if battery.level <= 20 && !battery.isCharging { return .orange }
        return battery.isLowPowerMode ? .yellow : .green
    }
}

struct ShelfPreviewCard: View {
    let model: NotchViewModel
    private let shelf = ShelfStore.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "Shelf", symbol: "tray.full.fill", tint: .accentColor) {
                    Text("\(shelf.items.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                }
                if shelf.items.isEmpty {
                    Spacer(minLength: 0)
                    Text("Drop files on the notch")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    // The latest files, large enough to recognize, each with its name; drag one
                    // straight out of the widget.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 8) {
                        ForEach(Array(shelf.items.suffix(6).reversed())) { item in
                            VStack(spacing: 3) {
                                Image(nsImage: shelf.thumbnails[item.id] ?? NSWorkspace.shared.icon(forFile: item.url.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 38, height: 38)
                                Text(verbatim: item.url.lastPathComponent)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(IslaInk.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
                            .help(item.url.lastPathComponent)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: item.url.lastPathComponent))
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Open Shelf") { model.select(.shelf) }
                        .buttonStyle(NotchPillButtonStyle())
                }
            }
        }
        .onDrop(of: ShelfStore.acceptedTypes, isTargeted: nil) { providers in
            shelf.add(providers: providers)
            return true
        }
    }
}
