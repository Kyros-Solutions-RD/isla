//
//  ClipboardView.swift
//  Isla
//

import SwiftUI

struct ClipboardView: View {
    @Bindable var model: NotchViewModel
    private let store = ClipboardStore.shared
    @State private var query = ""
    @State private var filter: ClipKind?
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        store.items.filter { item in
            (filter == nil || item.kind == filter) &&
            (query.isEmpty || item.preview.localizedCaseInsensitiveContains(query))
        }
        .sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.date > rhs.date
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .focused($searchFocused)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(.white.opacity(0.08)))
                .frame(maxWidth: 240)

                FilterChip(title: "All", symbol: "square.grid.2x2", selected: filter == nil) { filter = nil }
                ForEach([ClipKind.text, .link, .image, .file]) { kind in
                    FilterChip(title: kind.title, symbol: kind.symbol, selected: filter == kind) {
                        filter = filter == kind ? nil : kind
                    }
                }

                Spacer(minLength: 0)

                Button {
                    store.togglePause()
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(NotchIconButtonStyle(size: 26))
                .help(store.isPaused ? String(localized: "Resume capture") : String(localized: "Pause capture"))

                Menu {
                    Button("Clear History") { store.clearHistory() }
                    Button("Clear Everything, Including Pinned", role: .destructive) { store.clearHistory(keepPinned: false) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            if filtered.isEmpty {
                NotchEmptyState(symbol: "doc.on.clipboard",
                                title: query.isEmpty ? "Nothing copied yet" : "No matches",
                                message: query.isEmpty ? "Copy text, links, images or files and they will show up here. Passwords are never saved." : nil)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(filtered) { item in
                            ClipCard(item: item, model: model)
                                .scrollEdgeEase(.horizontal)
                        }
                    }
                }
            }
        }
        .onAppear {
            if model.controller?.panel.isKeyWindow == true { searchFocused = true }
        }
    }
}

private struct FilterChip: View {
    let title: LocalizedStringKey
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .foregroundStyle(selected ? Color.black : Color.white.opacity(0.8))
            .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

private struct ClipCard: View {
    let item: ClipItem
    let model: NotchViewModel
    private let store = ClipboardStore.shared
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon = NSWorkspace.shared.appIcon(bundleIdentifier: item.sourceBundleID) {
                    Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                } else {
                    Image(systemName: item.kind.symbol).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text(item.date, format: .relative(presentation: .named))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(IslaInk.faint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if item.isPinned || hovering {
                    Button { store.togglePin(item) } label: {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(item.isPinned ? Color.yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            content
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 168)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(hovering ? 0.12 : 0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(item.isPinned ? Color.yellow.opacity(0.35) : .white.opacity(0.06), lineWidth: 0.8)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .animation(IslaMotion.snappy, value: hovering)
        .onTapGesture { store.paste(item, closing: model.controller) }
        .onDrag { dragProvider }
        .contextMenu {
            Button("Paste") { store.paste(item, closing: model.controller) }
            Button("Copy") { store.copy(item) }
            Button(item.isPinned ? "Unpin" : "Pin") { store.togglePin(item) }
            if item.kind == .link, let text = item.text, let url = URL(string: text) {
                Button("Open Link") { NSWorkspace.shared.open(url) }
            }
            if item.kind == .text || item.kind == .link, let text = item.text {
                Button("Add to Shelf") { ShelfStore.shared.addText(text) }
            }
            Divider()
            Button("Delete", role: .destructive) { store.delete(item) }
        }
        .help(String(localized: "Click to paste"))
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: item.text ?? "") ?? .gray)
                    .frame(width: 34, height: 34)
                Text(item.text ?? "")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        case .link:
            VStack(alignment: .leading, spacing: 3) {
                Text(URL(string: item.text ?? "")?.host() ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(item.text ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(4)
            }
        case .file:
            HStack(spacing: 8) {
                if let first = item.fileURLs?.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .frame(width: 34, height: 34)
                }
                Text(item.preview)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(4)
            }
        case .text:
            Text(item.text ?? "")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(7)
        }
    }

    private var dragProvider: NSItemProvider {
        switch item.kind {
        case .file:
            if let url = item.fileURLs?.first { return NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        case .image:
            if let image = store.image(for: item) { return NSItemProvider(object: image) }
        default:
            break
        }
        return NSItemProvider(object: (item.text ?? "") as NSString)
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(red: Double((number >> 16) & 0xFF) / 255, green: Double((number >> 8) & 0xFF) / 255, blue: Double(number & 0xFF) / 255)
    }
}
