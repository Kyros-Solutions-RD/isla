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
                ForEach(widgets) { widget in
                    widgetView(widget)
                        .frame(width: unit * widget.span)
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
        }
    }
}

struct DevicesCard: View {
    private let battery = BatteryMonitor.shared
    private let bluetooth = BluetoothMonitor.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "Battery", symbol: "battery.75percent", tint: .green)
                if battery.hasBattery {
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer").font(.system(size: 14)).frame(width: 20)
                        Text("Mac").font(.system(size: 11.5, weight: .medium))
                        Spacer()
                        Text("\(battery.level)%").font(.system(size: 11.5, weight: .semibold, design: .rounded)).monospacedDigit()
                        BatteryGlyph(level: battery.level, charging: battery.isCharging, width: 20)
                    }
                }
                ForEach(bluetooth.connected.prefix(3)) { device in
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
                    HStack(spacing: -10) {
                        ForEach(shelf.items.suffix(4)) { item in
                            Image(nsImage: shelf.thumbnails[item.id] ?? NSWorkspace.shared.icon(forFile: item.url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .shadow(radius: 3)
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
