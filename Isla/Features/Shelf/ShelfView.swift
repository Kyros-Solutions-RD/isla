//
//  ShelfView.swift
//  Isla
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @Bindable var model: NotchViewModel
    private let shelf = ShelfStore.shared

    var body: some View {
        HStack(spacing: 12) {
            if model.isDraggingFiles {
                DropTargets()
                    .transition(.blurReplace)
            } else if shelf.items.isEmpty {
                EmptyShelf()
                    .transition(.blurReplace)
            } else {
                ShelfGrid()
                    .transition(.blurReplace)
                ShelfActions()
                    .frame(width: 132)
            }
        }
        .animation(IslaMotion.content, value: model.isDraggingFiles)
        .animation(IslaMotion.content, value: shelf.items.isEmpty)
    }
}

private struct EmptyShelf: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
                .foregroundStyle(.white.opacity(0.18))
            NotchEmptyState(symbol: "tray.and.arrow.down",
                            title: "Drop files here",
                            message: "Drag files onto the notch to keep them handy. Shake while dragging to open a Pocket anywhere.")
        }
    }
}

/// Two big targets that appear while files are being dragged.
private struct DropTargets: View {
    var body: some View {
        HStack(spacing: 12) {
            DropTarget(symbol: "tray.and.arrow.down.fill", title: "Keep on Shelf", tint: .accentColor) { providers in
                ShelfStore.shared.add(providers: providers)
            }
            DropTarget(symbol: "airplayaudio", title: "AirDrop", tint: .blue, customSymbol: "AirDrop") { providers in
                Task {
                    let urls = await providers.loadFileURLs()
                    ShelfStore.shared.airDrop(urls: urls)
                }
            }
        }
    }
}

private struct DropTarget: View {
    let symbol: String
    let title: LocalizedStringKey
    let tint: Color
    var customSymbol: String? = nil
    let perform: ([NSItemProvider]) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(targeted ? 0.35 : 0.18))
                    .frame(width: 58, height: 58)
                Image(systemName: customSymbol == "AirDrop" ? "dot.radiowaves.up.forward" : symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint == .accentColor ? Color.white : tint)
                    .symbolEffect(.bounce, value: targeted)
            }
            .scaleEffect(targeted ? 1.08 : 1)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                .fill(.white.opacity(targeted ? 0.12 : 0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                        .strokeBorder(tint.opacity(targeted ? 0.8 : 0.2), lineWidth: 1.2)
                }
        }
        .animation(IslaMotion.snappy, value: targeted)
        .onDrop(of: ShelfStore.acceptedTypes, isTargeted: $targeted) { providers in
            perform(providers)
            Haptics.tap(.levelChange)
            return true
        }
    }
}

private struct ShelfGrid: View {
    private let shelf = ShelfStore.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(shelf.items) { item in
                    ShelfTile(item: item)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                .fill(.white.opacity(0.05))
        }
        .onDrop(of: ShelfStore.acceptedTypes, isTargeted: nil) { providers in
            shelf.add(providers: providers)
            return true
        }
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    private let shelf = ShelfStore.shared
    @State private var hovering = false

    var body: some View {
        let selected = shelf.selection.contains(item.id)
        VStack(spacing: 6) {
            Group {
                if let thumbnail = shelf.thumbnails[item.id] {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 60, height: 60)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

            Text(item.name)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 84)
        }
        .padding(8)
        .frame(width: 100)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.35) : .white.opacity(hovering ? 0.08 : 0))
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .heavy))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.black.opacity(0.65)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .animation(IslaMotion.snappy, value: hovering)
        .onTapGesture(count: 2) { shelf.open(item) }
        .simultaneousGesture(TapGesture().onEnded {
            shelf.toggleSelection(item, extend: NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift))
        })
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        } preview: {
            Image(nsImage: shelf.thumbnails[item.id] ?? NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 64, height: 64)
        }
        .contextMenu {
            Button("Open") { shelf.open(item) }
            Button("Quick Look") { QuickLookController.shared.show([item.url]) }
            Button("Show in Finder") { shelf.reveal([item]) }
            Button("Copy") { shelf.copyToPasteboard([item]) }
            Button("AirDrop") { shelf.airDrop([item]) }
            Menu("Convert") {
                ForEach(ConversionTarget.available(for: [item.url])) { target in
                    Button(target.title) { FileConverter.convert([item.url], to: target) }
                }
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) { shelf.remove(item) }
        }
        .help(item.url.path)
    }
}

private struct ShelfActions: View {
    private let shelf = ShelfStore.shared
    @State private var shareAnchor: NSView?

    var body: some View {
        let targets = shelf.selectedItems
        VStack(spacing: 6) {
            Text(shelf.selection.isEmpty ? "\(shelf.items.count) items" : "\(shelf.selection.count) selected")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            ShelfActionButton(title: "AirDrop", symbol: "dot.radiowaves.up.forward") { shelf.airDrop(targets) }
            ShelfActionButton(title: "Share…", symbol: "square.and.arrow.up") {
                SharingPicker.show(items: targets.map(\.url), relativeTo: shareAnchor)
            }
            .background(ViewAnchor(view: $shareAnchor))

            Menu {
                ForEach(ConversionTarget.available(for: targets.map(\.url))) { target in
                    Button { FileConverter.convert(targets.map(\.url), to: target) } label: {
                        Label(target.title, systemImage: target.symbol)
                    }
                }
            } label: {
                ShelfActionLabel(title: "Convert", symbol: "arrow.triangle.2.circlepath")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)

            ShelfActionButton(title: "Remove All", symbol: "trash", tint: .red.opacity(0.9)) { shelf.clear() }

            if let busy = shelf.busyMessage {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(busy).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ShelfActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ShelfActionLabel(title: title, symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct ShelfActionLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    var tint: Color = .white
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(hovering ? 0.13 : 0.07))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Helpers

extension Array where Element == NSItemProvider {
    func loadFileURLs() async -> [URL] {
        var urls: [URL] = []
        for provider in self where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
            }
            if let url { urls.append(url) }
        }
        return urls
    }
}

/// Captures the backing NSView so AppKit pickers can anchor to SwiftUI content.
struct ViewAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.view = view }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum SharingPicker {
    @MainActor
    static func show(items: [Any], relativeTo view: NSView?) {
        guard let view, !items.isEmpty else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
