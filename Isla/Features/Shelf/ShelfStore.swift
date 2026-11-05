//
//  ShelfStore.swift
//  Isla
//
//  A temporary home for files: drop them on the notch, drag them back out
//  anywhere, AirDrop or convert them.
//

import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Codable, Hashable {
    let id: UUID
    var url: URL
    var addedAt: Date
    /// Created by Isla (dropped text, images, conversions) and safe to delete.
    var isGenerated: Bool

    var name: String { url.lastPathComponent }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}

@Observable
@MainActor
final class ShelfStore {
    static let shared = ShelfStore()
    static let acceptedTypes: [UTType] = [.fileURL, .url, .image, .plainText, .utf8PlainText]

    private(set) var items: [ShelfItem] = []
    private(set) var thumbnails: [UUID: NSImage] = [:]
    var selection: Set<UUID> = []
    private(set) var busyMessage: String?

    private let fileName = "shelf.json"
    private let generatedFolder = Storage.folder("Shelf")

    private init() {
        if Preferences.shared.rememberShelf, let saved = Storage.load([ShelfItem].self, from: fileName) {
            items = saved.filter(\.exists)
            items.forEach(loadThumbnail)
        }
    }

    var selectedItems: [ShelfItem] {
        let chosen = items.filter { selection.contains($0.id) }
        return chosen.isEmpty ? items : chosen
    }

    // MARK: Adding

    func add(urls: [URL], generated: Bool = false) {
        let existing = Set(items.map(\.url))
        let fresh = urls.filter { !existing.contains($0) }.map {
            ShelfItem(id: UUID(), url: $0, addedAt: .now, isGenerated: generated)
        }
        guard !fresh.isEmpty else { return }
        withAnimation(IslaMotion.content) { items.append(contentsOf: fresh) }
        fresh.forEach(loadThumbnail)
        persist()
        LiveActivityCenter.shared.post(.shelf(count: items.count), duration: 1.8)
    }

    func add(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in ShelfStore.shared.add(urls: [url]) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in ShelfStore.shared.addGenerated(data: data, name: "Image", ext: "png", convertImage: true) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in ShelfStore.shared.addLink(url) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text, !text.isEmpty else { return }
                    Task { @MainActor in ShelfStore.shared.addText(text) }
                }
            }
        }
    }

    func addText(_ text: String) {
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.hasPrefix("http") == true {
            addLink(url)
            return
        }
        let title = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Text"
        addGenerated(data: Data(text.utf8), name: String(title.prefix(40)), ext: "txt")
    }

    func addLink(_ url: URL) {
        let contents = "[InternetShortcut]\nURL=\(url.absoluteString)\n"
        addGenerated(data: Data(contents.utf8), name: url.host() ?? "Link", ext: "url")
    }

    func addGenerated(data: Data, name: String, ext: String, convertImage: Bool = false) {
        var payload = data
        if convertImage, let image = NSImage(data: data), let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            payload = png
        }
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = uniqueURL(in: generatedFolder, name: safe, ext: ext)
        do {
            try payload.write(to: url)
            add(urls: [url], generated: true)
        } catch {
            NSSound.beep()
        }
    }

    func uniqueURL(in folder: URL, name: String, ext: String) -> URL {
        var candidate = folder.appendingPathComponent(name).appendingPathExtension(ext)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }

    #if DEBUG
    func applyDemo() {
        clear()
        let art = DemoArt.album(size: 900)
        if let tiff = art.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            addGenerated(data: png, name: "Atardecer en el Malecón", ext: "png")
        }
        addGenerated(data: Data("Notas de lanzamiento de Isla 1.0".utf8), name: "Notas de lanzamiento", ext: "txt")
        let pdf = generatedFolder.appendingPathComponent("Propuesta Isla.pdf")
        let document = NSMutableData()
        if let consumer = CGDataConsumer(data: document as CFMutableData) {
            var box = CGRect(x: 0, y: 0, width: 612, height: 792)
            if let context = CGContext(consumer: consumer, mediaBox: &box, nil) {
                context.beginPDFPage(nil)
                context.setFillColor(NSColor(red: 0.05, green: 0.1, blue: 0.17, alpha: 1).cgColor)
                context.fill(CGRect(x: 0, y: 560, width: 612, height: 232))
                context.setFillColor(NSColor(red: 1, green: 0.42, blue: 0.29, alpha: 1).cgColor)
                context.fill(CGRect(x: 48, y: 470, width: 220, height: 18))
                context.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
                for row in 0..<12 { context.fill(CGRect(x: 48, y: 420 - row * 26, width: 516 - (row % 3) * 60, height: 9)) }
                context.endPDFPage()
                context.closePDF()
            }
        }
        try? (document as Data).write(to: pdf)
        add(urls: [pdf], generated: true)
        addGenerated(data: Data(), name: "Presupuesto 2027", ext: "numbers")
        addGenerated(data: Data(), name: "Demo del notch", ext: "mov")
    }
    #endif

    // MARK: Removing

    func remove(_ item: ShelfItem) {
        withAnimation(IslaMotion.content) {
            items.removeAll { $0.id == item.id }
        }
        selection.remove(item.id)
        thumbnails[item.id] = nil
        if item.isGenerated { try? FileManager.default.removeItem(at: item.url) }
        persist()
    }

    func clear() {
        let generated = items.filter(\.isGenerated)
        withAnimation(IslaMotion.content) { items.removeAll() }
        selection.removeAll()
        thumbnails.removeAll()
        generated.forEach { try? FileManager.default.removeItem(at: $0.url) }
        persist()
    }

    func toggleSelection(_ item: ShelfItem, extend: Bool) {
        if extend {
            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
        } else {
            selection = selection == [item.id] ? [] : [item.id]
        }
    }

    // MARK: Actions

    func open(_ item: ShelfItem) { NSWorkspace.shared.open(item.url) }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
    }

    func copyToPasteboard(_ items: [ShelfItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
        LiveActivityCenter.shared.post(.message(symbol: "doc.on.doc.fill", title: String(localized: "Copied")), duration: 1.4)
    }

    func airDrop(_ items: [ShelfItem]) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        let urls = items.map(\.url)
        if service.canPerform(withItems: urls) {
            NSApp.activate()
            service.perform(withItems: urls)
        }
    }

    func airDrop(urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else { return }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    func setBusy(_ message: String?) {
        busyMessage = message
    }

    // MARK: Persistence & thumbnails

    private func persist() {
        guard Preferences.shared.rememberShelf else { return }
        Storage.save(items, to: fileName)
    }

    private func loadThumbnail(_ item: ShelfItem) {
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 128, height: 128),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            let image = representation?.nsImage
            Task { @MainActor in
                ShelfStore.shared.thumbnails[item.id] = image ?? NSWorkspace.shared.icon(forFile: item.url.path)
            }
        }
    }
}
