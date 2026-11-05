//
//  NotesStore.swift
//  Isla
//

import AppKit
import SwiftUI

struct QuickNote: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var updated: Date
    var isPinned: Bool = false

    var title: String {
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return first.trimmingCharacters(in: .whitespaces).nonEmpty ?? String(localized: "New Note")
    }

    var body: String {
        let lines = text.split(whereSeparator: \.isNewline).dropFirst()
        return lines.joined(separator: " ")
    }
}

@Observable
@MainActor
final class NotesStore {
    static let shared = NotesStore()

    private(set) var notes: [QuickNote] = []
    var selectedID: UUID?

    @ObservationIgnored private let fileName = "notes.json"
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private init() {
        notes = Storage.load([QuickNote].self, from: fileName) ?? []
        if notes.isEmpty {
            notes = [QuickNote(id: UUID(), text: String(localized: "Welcome to Isla Notes\nJot anything down. Notes stay on this Mac."), updated: .now)]
        }
        selectedID = sorted.first?.id
    }

    var sorted: [QuickNote] {
        notes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updated > rhs.updated
        }
    }

    var selected: QuickNote? {
        notes.first { $0.id == selectedID }
    }

    @discardableResult
    func create(text: String = "") -> QuickNote {
        let note = QuickNote(id: UUID(), text: text, updated: .now)
        withAnimation(IslaMotion.content) { notes.append(note) }
        selectedID = note.id
        scheduleSave()
        return note
    }

    func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].updated = .now
        scheduleSave()
    }

    func delete(_ note: QuickNote) {
        withAnimation(IslaMotion.content) { notes.removeAll { $0.id == note.id } }
        if selectedID == note.id { selectedID = sorted.first?.id }
        scheduleSave()
    }

    func togglePin(_ note: QuickNote) {
        guard let index = notes.firstIndex(of: note) else { return }
        notes[index].isPinned.toggle()
        scheduleSave()
    }

    /// Sends a note to Apple Notes.
    func exportToAppleNotes(_ note: QuickNote) {
        let html = note.text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")
        Task {
            let result = await Shell.appleScript("tell application \"Notes\" to make new note with properties {body:\"\(html)\"}")
            LiveActivityCenter.shared.post(.message(symbol: result == nil ? "exclamationmark.triangle.fill" : "note.text",
                                                    title: result == nil ? String(localized: "Notes unavailable") : String(localized: "Saved to Notes")),
                                           duration: 1.6)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            Storage.save(self.notes, to: self.fileName)
        }
    }
}
