//
//  NotesView.swift
//  Isla
//

import SwiftUI

struct NotesView: View {
    @Bindable var model: NotchViewModel
    private let store = NotesStore.shared

    var body: some View {
        HStack(spacing: 12) {
            IslaCard(padding: 8) {
                VStack(spacing: 4) {
                    HStack {
                        Text("Notes").font(.system(size: 13, weight: .bold))
                        Spacer()
                        Button { store.create() } label: { Image(systemName: "square.and.pencil") }
                            .buttonStyle(NotchIconButtonStyle(size: 24))
                            .help(String(localized: "New Note"))
                            .accessibilityLabel(Text("New Note"))
                    }
                    .padding(.horizontal, 4)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 2) {
                            ForEach(store.sorted) { note in
                                NoteRow(note: note, selected: store.selectedID == note.id)
                                    .onTapGesture { store.selectedID = note.id }
                                    .scrollEdgeEase()
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollFade()
                }
            }
            .frame(width: 200)

            IslaCard(padding: 0) {
                if let note = store.selected {
                    NoteEditor(note: note)
                        .id(note.id)
                } else {
                    NotchEmptyState(symbol: "note.text", title: "No note selected", actionTitle: "New Note") { store.create() }
                }
            }
        }
    }
}

private struct NoteRow: View {
    let note: QuickNote
    let selected: Bool
    private let store = NotesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                }
                Text(note.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            Text(note.updated, format: .relative(presentation: .named))
                .font(.system(size: 9.5))
                .foregroundStyle(IslaInk.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.white.opacity(0.14) : .clear)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") { store.togglePin(note) }
            Button("Save to Apple Notes") { store.exportToAppleNotes(note) }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { store.delete(note) }
        }
    }
}

private struct NoteEditor: View {
    let note: QuickNote
    @State private var text: String
    private let store = NotesStore.shared

    init(note: QuickNote) {
        self.note = note
        _text = State(initialValue: note.text)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .onChange(of: text) { _, newValue in store.update(note.id, text: newValue) }

            HStack(spacing: 4) {
                Text("\(text.split { $0.isWhitespace || $0.isNewline }.count) words")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(IslaInk.faint)
                Button { store.exportToAppleNotes(note) } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(NotchIconButtonStyle(size: 22))
                    .help(String(localized: "Save to Apple Notes"))
                    .accessibilityLabel(Text("Save to Apple Notes"))
                Button { store.delete(note) } label: { Image(systemName: "trash") }
                    .buttonStyle(NotchIconButtonStyle(size: 22))
                    .help(String(localized: "Delete"))
                    .accessibilityLabel(Text("Delete"))
            }
            .padding(6)
        }
    }
}

/// Quick note widget for the Nook.
struct QuickNoteCard: View {
    private let store = NotesStore.shared
    @State private var draft = ""

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(title: "Quick Note", symbol: "note.text", tint: .yellow)
                TextField("Write something…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(4...6)
                    .onSubmit(save)
                Spacer(minLength: 0)
                HStack {
                    Text("\(store.notes.count) notes").font(.system(size: 10)).foregroundStyle(IslaInk.faint)
                    Spacer()
                    Button("Save") { save() }
                        .buttonStyle(NotchPillButtonStyle())
                        .disabled(draft.isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.create(text: trimmed)
        draft = ""
        Haptics.tap(.levelChange)
    }
}
