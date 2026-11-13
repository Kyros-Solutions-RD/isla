//
//  LocalChatView.swift
//  Isla
//
//  The Chat tab: a conversation with a model in Ollama or LM Studio, right under the camera.
//

import AppKit
import SwiftUI

struct LocalChatView: View {
    @Bindable var model: NotchViewModel
    private let chat = LocalChat.shared
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if !chat.hasChecked {
                Color.clear
            } else if chat.models.isEmpty {
                ChatNoServer()
                    .transition(.blurReplace)
            } else {
                header
                    .emerge(delay: 0.03, offset: CGSize(width: 0, height: -6))
                if chat.messages.isEmpty {
                    ChatSuggestions { prompt in chat.send(prompt) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity)
                } else {
                    conversation
                        .transition(.opacity)
                }
                input
                    .emerge(delay: 0.08, offset: CGSize(width: 0, height: 6))
            }
        }
        .animation(IslaMotion.snappy, value: chat.models.isEmpty)
        .animation(IslaMotion.snappy, value: chat.messages.isEmpty)
        .task {
            await chat.refreshModels()
            try? await Task.sleep(for: .milliseconds(60))
            focused = true
        }
        .onAppear { model.holds.insert("chat") }
        .onDisappear { model.holds.remove("chat") }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(chat.models) { option in
                    Button {
                        LocalChat.shared.selectedID = option.id
                    } label: {
                        Text(verbatim: "\(option.shortName) · \(option.server.name)\(option.loaded ? " ●" : "")")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.purple)
                    Text(verbatim: chat.selected?.shortName ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(verbatim: chat.selected?.server.name ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.08)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text("Model"))

            Label("On this Mac", systemImage: "lock.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.green.opacity(0.85))
            Spacer(minLength: 0)
            if !chat.messages.isEmpty {
                Button {
                    withAnimation(IslaMotion.snappy) { chat.clear() }
                    focused = true
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .buttonStyle(NotchPillButtonStyle())
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(chat.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .offset(y: 10).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)),
                                removal: .opacity))
                    }
                    if let failure = chat.failure {
                        Label(failure, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 4)
            }
            .scrollFade(top: 6, bottom: 10)
            .onChange(of: chat.messages.last?.text) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(IslaMotion.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .animation(IslaMotion.snappy, value: chat.messages.count)
    }

    private var input: some View {
        HStack(spacing: 8) {
            TextField("Ask \(chat.modelLabel)…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...3)
                .focused($focused)
                .onSubmit(submit)
                .disabled(chat.isResponding)
            Button {
                chat.isResponding ? chat.stop() : submit()
            } label: {
                Image(systemName: chat.isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(chat.isResponding ? Color.white : (draft.isEmpty ? Color.white.opacity(0.25) : Color.accentColor))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressSqueeze())
            .disabled(!chat.isResponding && draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(chat.isResponding ? Text("Stop") : Text("Send"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(focused ? 0.11 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(focused ? 0.18 : 0.07), lineWidth: 0.6)
                }
        }
        .animation(.easeOut(duration: 0.18), value: focused)
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(IslaMotion.snappy) { chat.send(text) }
        draft = ""
        Haptics.tap()
    }
}

// MARK: - Bubbles

private struct ChatBubble: View {
    let message: LocalChat.Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: 60) }
            Group {
                if message.thinking && message.text.isEmpty {
                    HStack(spacing: 6) {
                        ThinkingDots(tint: .white.opacity(0.7), dot: 4)
                            .frame(width: 24, height: 8)
                        Text("Thinking…")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Text(Self.markdown(message.text))
                        .font(.system(size: 12.5))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(message.role == .user ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08))
            }
            .contextMenu {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.text, forType: .string)
                }
            }
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

// MARK: - Empty states

/// Ready to chat: a few starting points, the useful ones built from what you last copied.
private struct ChatSuggestions: View {
    let ask: (String) -> Void

    private var clipboardText: String? {
        ClipboardStore.shared.items.first(where: { $0.kind == .text })?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask anything. Your words stay on this Mac.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                if let copied = clipboardText, !copied.isEmpty {
                    suggestion("Summarize what I copied", symbol: "text.append") {
                        ask(String(localized: "Summarize this in a few lines:") + "\n\n" + copied)
                    }
                    suggestion("Translate what I copied", symbol: "character.bubble") {
                        ask(String(localized: "Translate this to English (or to Spanish if it is already in English):") + "\n\n" + copied)
                    }
                    suggestion("Explain what I copied", symbol: "lightbulb") {
                        ask(String(localized: "Explain this simply:") + "\n\n" + copied)
                    }
                } else {
                    suggestion("Write a short email", symbol: "envelope") {
                        ask(String(localized: "Help me write a short, friendly email."))
                    }
                    suggestion("Brainstorm ideas", symbol: "lightbulb") {
                        ask(String(localized: "Give me five quick ideas for my next project."))
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func suggestion(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.08)))
        }
        .buttonStyle(PressSqueeze())
    }
}

/// No model server is running: say how to get one, without starting anything.
private struct ChatNoServer: View {
    private let apps = LocalChat.installedServerApps()

    var body: some View {
        // The buttons sit right under the words, and the group is centered as one.
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            NotchEmptyState(symbol: "bubble.left.and.text.bubble.right",
                            title: "Chat with your local models",
                            message: "Open Ollama or LM Studio and load a model. Everything stays on this Mac, with no account and no internet.")
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(apps, id: \.url) { app in
                    Button {
                        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
                        Task {
                            for _ in 0..<10 {
                                try? await Task.sleep(for: .seconds(2))
                                await LocalChat.shared.refreshModels(force: true)
                                if LocalChat.shared.canAsk { break }
                            }
                        }
                    } label: {
                        Text("Open \(app.name)")
                    }
                    .buttonStyle(NotchPillButtonStyle())
                }
                Button("Check Again") {
                    Task { await LocalChat.shared.refreshModels(force: true) }
                }
                .buttonStyle(NotchPillButtonStyle(tint: .secondary))
            }
            .emerge(delay: 0.2, offset: CGSize(width: 0, height: -5))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
