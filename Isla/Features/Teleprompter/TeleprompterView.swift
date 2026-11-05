//
//  TeleprompterView.swift
//  Isla
//

import SwiftUI

struct TeleprompterView: View {
    @Bindable var model: NotchViewModel
    @Bindable private var store = TeleprompterStore.shared
    @Bindable private var prefs = Preferences.shared
    @State private var editing = false
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var lastTick: Date?

    var body: some View {
        HStack(spacing: 12) {
            ScriptPicker(editing: $editing)
                .frame(width: 150)

            ZStack {
                if editing, let script = store.selected {
                    ScriptEditor(script: script)
                } else if let script = store.selected {
                    prompter(script)
                } else {
                    NotchEmptyState(symbol: "text.alignleft", title: "No script", actionTitle: "New Script") {
                        store.create()
                        editing = true
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
                .frame(width: 112)
        }
        .onAppear { model.holds.insert("prompter") }
        .onDisappear {
            model.holds.remove("prompter")
            store.isPlaying = false
            store.followVoice = false
        }
    }

    private func prompter(_ script: PrompterScript) -> some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !store.isPlaying || store.followVoice)) { context in
                Text(script.text.isEmpty ? String(localized: "Write your script to get started.") : script.text)
                    .font(.system(size: prefs.prompterFontSize, weight: .semibold, design: .rounded))
                    .lineSpacing(prefs.prompterFontSize * 0.35)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, proxy.size.height * 0.35)
                    .padding(.bottom, proxy.size.height * 0.6)
                    .background {
                        GeometryReader { text in
                            Color.clear.onAppear { contentHeight = text.size.height }
                                .onChange(of: text.size.height) { _, height in contentHeight = height }
                        }
                    }
                    .offset(y: -currentOffset(viewport: proxy.size.height))
                    .scaleEffect(x: prefs.prompterMirror ? -1 : 1, y: 1)
                    .onChange(of: context.date) { _, date in advance(to: date) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                       .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .onAppear { viewportHeight = proxy.size.height }
            .contentShape(Rectangle())
            .onTapGesture { store.togglePlay() }
            .gesture(DragGesture().onChanged { value in
                store.offset = max(0, store.offset - value.velocity.height / 120)
            })
        }
        .animation(store.followVoice ? .smooth(duration: 0.6) : nil, value: store.voiceProgress)
    }

    private func currentOffset(viewport: CGFloat) -> CGFloat {
        let maxOffset = max(0, contentHeight - viewport * 0.9)
        if store.followVoice {
            return min(maxOffset, CGFloat(store.voiceProgress) * maxOffset)
        }
        return min(maxOffset, store.offset)
    }

    private func advance(to date: Date) {
        defer { lastTick = date }
        guard let lastTick, store.isPlaying, !store.followVoice else { return }
        let delta = date.timeIntervalSince(lastTick)
        guard delta < 0.5 else { return }
        store.offset += CGFloat(prefs.prompterSpeed * delta)
        if store.offset > contentHeight { store.isPlaying = false }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button { store.restart() } label: { Image(systemName: "backward.end.fill") }
                    .buttonStyle(NotchIconButtonStyle(size: 30))
                    .help(String(localized: "Restart"))
                Button {
                    lastTick = nil
                    store.togglePlay()
                } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(NotchIconButtonStyle(size: 38, prominent: true))
                .disabled(store.followVoice)
            }

            ValueStepper(symbol: "hare.fill", value: $prefs.prompterSpeed, range: 10...140, step: 6,
                         help: String(localized: "Speed"))
            ValueStepper(symbol: "textformat.size", value: $prefs.prompterFontSize, range: 14...40, step: 2,
                         help: String(localized: "Text size"))

            Toggle(isOn: $store.followVoice) {
                Label("Follow voice", systemImage: "waveform")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .toggleStyle(.button)
            .buttonStyle(NotchPillButtonStyle(tint: store.followVoice ? .green : .white))

            Toggle(isOn: $prefs.prompterMirror) {
                Label("Mirror", systemImage: "arrow.left.and.right")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .toggleStyle(.button)
            .buttonStyle(NotchPillButtonStyle(tint: prefs.prompterMirror ? .blue : .white))
            Spacer(minLength: 0)
        }
    }
}

private struct ValueStepper: View {
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let help: String

    var body: some View {
        HStack(spacing: 2) {
            Button { value = max(range.lowerBound, value - step) } label: { Image(systemName: "minus") }
                .buttonStyle(NotchIconButtonStyle(size: 22))
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Button { value = min(range.upperBound, value + step) } label: { Image(systemName: "plus") }
                .buttonStyle(NotchIconButtonStyle(size: 22))
        }
        .padding(.horizontal, 3)
        .frame(height: 28)
        .background(Capsule().fill(.white.opacity(0.07)))
        .help(help)
    }
}

private struct ScriptPicker: View {
    @Binding var editing: Bool
    private let store = TeleprompterStore.shared

    var body: some View {
        IslaCard(padding: 8) {
            VStack(spacing: 4) {
                HStack {
                    Text("Scripts").font(.system(size: 12.5, weight: .bold))
                    Spacer()
                    Button {
                        store.create()
                        editing = true
                    } label: { Image(systemName: "plus") }
                    .buttonStyle(NotchIconButtonStyle(size: 22))
                }
                .padding(.horizontal, 4)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(store.scripts) { script in
                            let selected = store.selectedID == script.id
                            Text(script.title)
                                .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.white.opacity(0.14) : .clear))
                                .contentShape(Rectangle())
                                .onTapGesture { store.select(script) }
                                .contextMenu {
                                    Button("Delete", role: .destructive) { store.delete(script) }
                                }
                        }
                    }
                }
                Button(editing ? "Done" : "Edit Script") { editing.toggle() }
                    .buttonStyle(NotchPillButtonStyle())
            }
        }
    }
}

private struct ScriptEditor: View {
    let script: PrompterScript
    @State private var title: String
    @State private var text: String
    private let store = TeleprompterStore.shared

    init(script: PrompterScript) {
        self.script = script
        _title = State(initialValue: script.title)
        _text = State(initialValue: script.text)
    }

    var body: some View {
        IslaCard(padding: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .onChange(of: title) { _, value in store.update(script.id, title: value) }
                TextEditor(text: $text)
                    .font(.system(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .onChange(of: text) { _, value in store.update(script.id, text: value) }
            }
        }
    }
}
