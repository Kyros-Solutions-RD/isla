//
//  ShortcutsView.swift
//  Isla
//
//  Runs your Shortcuts through the system `shortcuts` command.
//

import SwiftUI

@Observable
@MainActor
final class ShortcutsService {
    static let shared = ShortcutsService()

    private(set) var all: [String] = []
    private(set) var running: String?
    private(set) var lastResult: (name: String, success: Bool)?
    private(set) var loaded = false

    private init() {}

    var favorites: [String] {
        let favorites = Preferences.shared.favoriteShortcuts
        return favorites.filter { all.isEmpty || all.contains($0) }
    }

    func reload() async {
        let result = await Shell.run("/usr/bin/shortcuts", ["list"])
        all = result.output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.sorted()
        loaded = true
    }

    func run(_ name: String) {
        guard running == nil else { return }
        running = name
        Haptics.tap()
        Task {
            let result = await Shell.run("/usr/bin/shortcuts", ["run", name])
            running = nil
            lastResult = (name, result.status == 0)
            LiveActivityCenter.shared.post(.message(symbol: result.status == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                                    title: name), duration: 1.8)
        }
    }

    func toggleFavorite(_ name: String) {
        var favorites = Preferences.shared.favoriteShortcuts
        if let index = favorites.firstIndex(of: name) { favorites.remove(at: index) } else { favorites.append(name) }
        Preferences.shared.favoriteShortcuts = favorites
    }
}

struct ShortcutsView: View {
    @Bindable var model: NotchViewModel
    private let service = ShortcutsService.shared
    @State private var query = ""

    private var list: [String] {
        let source = query.isEmpty ? (service.favorites.isEmpty ? service.all : service.favorites + service.all.filter { !service.favorites.contains($0) }) : service.all
        return query.isEmpty ? source : source.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("Search Shortcuts", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(.white.opacity(0.08)))
                .frame(maxWidth: 260)
                Spacer()
                Button {
                    Task { await service.reload() }
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(NotchIconButtonStyle(size: 26))
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                } label: { Image(systemName: "arrow.up.forward.app") }
                .buttonStyle(NotchIconButtonStyle(size: 26))
                .help(String(localized: "Open Shortcuts"))
            }

            if !service.loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if list.isEmpty {
                NotchEmptyState(symbol: "square.stack.3d.up", title: "No shortcuts found",
                                message: "Create shortcuts in the Shortcuts app and run them from here.")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(list, id: \.self) { name in
                            ShortcutTile(name: name)
                                .scrollEdgeEase()
                        }
                    }
                    .padding(.bottom, 8)
                }
                // The last row eases out at the edge instead of being cut.
                .scrollFade()
            }
        }
        .task { if !service.loaded { await service.reload() } }
    }
}

private struct ShortcutTile: View {
    let name: String
    private let service = ShortcutsService.shared
    @State private var hovering = false

    var body: some View {
        let favorite = Preferences.shared.favoriteShortcuts.contains(name)
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .green, .red]
        let tint = palette[name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % palette.count]

        Button { service.run(name) } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.gradient)
                    if service.running == name {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 11, weight: .semibold))
                    }
                }
                .frame(width: 26, height: 26)
                Text(name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if favorite {
                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                }
            }
            .padding(8)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(hovering ? 0.13 : 0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(favorite ? "Remove from Favorites" : "Add to Favorites") { service.toggleFavorite(name) }
            Button("Run") { service.run(name) }
        }
    }
}

/// Favorite Shortcuts widget for the Nook.
struct ShortcutsCard: View {
    private let service = ShortcutsService.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(title: "Shortcuts", symbol: "square.stack.3d.up.fill", tint: .purple)
                let items = Array((service.favorites.isEmpty ? service.all : service.favorites).prefix(4))
                if items.isEmpty {
                    Spacer(minLength: 0)
                    Text("Add favorites from the Shortcuts tab.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    ForEach(items, id: \.self) { name in
                        Button { service.run(name) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: service.running == name ? "hourglass" : "play.circle.fill")
                                    .foregroundStyle(.purple)
                                Text(name).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .task { if !service.loaded { await service.reload() } }
    }
}
