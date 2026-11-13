//
//  LauncherView.swift
//  Isla
//
//  The launcher tab: one field for apps, files, Isla, the clipboard, sums and conversions.
//  ↑↓ move, Return opens (or copies an answer), ⌘Return shows a file in Finder.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LauncherView: View {
    @Bindable var model: NotchViewModel
    @Bindable private var engine = LauncherEngine.shared
    @FocusState private var focused: Bool
    @Namespace private var selection

    var body: some View {
        VStack(spacing: 8) {
            field
                .emerge(delay: 0.04, offset: CGSize(width: 0, height: -6))
            if engine.query.trimmingCharacters(in: .whitespaces).isEmpty {
                LauncherHome(engine: engine) { example in engine.query = example }
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else {
                results
                    .transition(.opacity)
            }
        }
        .animation(IslaMotion.snappy, value: engine.query.isEmpty)
        .onAppear {
            engine.prepare()
            model.holds.insert("launcher")
        }
        .task {
            // The panel becomes key a moment after it opens.
            try? await Task.sleep(for: .milliseconds(80))
            focused = true
        }
        .onDisappear {
            model.holds.remove("launcher")
            engine.reset()
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(focused ? 0.8 : 0.5))
            TextField("Search apps, files, Isla, or calculate…", text: $engine.query)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium))
                .focused($focused)
                .onSubmit { engine.runSelected() }
                .onKeyPress(.downArrow) { engine.move(1); return .handled }
                .onKeyPress(.upArrow) { engine.move(-1); return .handled }
                .onKeyPress(keys: [.return], phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    engine.runSelected(reveal: true)
                    return .handled
                }
                .accessibilityLabel(Text("Search"))
            if let flash = engine.flash {
                Label(flash, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if engine.query.isEmpty, let combo = Preferences.shared.launcherHotKey {
                Text(verbatim: combo.display)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.08)))
            } else if !engine.query.isEmpty {
                Button {
                    engine.query = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(focused ? 0.11 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(focused ? 0.2 : 0.08), lineWidth: 0.6)
                }
        }
        .animation(.easeOut(duration: 0.18), value: focused)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    if let answer = engine.answer {
                        AnswerCard(result: answer, selected: engine.selectedID == answer.id)
                            .id(answer.id)
                            .onTapGesture { engine.selectedID = answer.id; engine.runSelected() }
                            .transition(.asymmetric(insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                                    removal: .opacity))
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(engine.results.enumerated()), id: \.element.id) { index, result in
                        LauncherRow(result: result, selected: engine.selectedID == result.id, selection: selection)
                            .id(result.id)
                            .onTapGesture {
                                engine.selectedID = result.id
                                engine.runSelected()
                            }
                            .onHover { inside in
                                if inside { withAnimation(IslaMotion.snappy) { engine.selectedID = result.id } }
                            }
                            .emerge(delay: Double(min(index, 6)) * 0.022, offset: CGSize(width: 0, height: -4))
                            .scrollEdgeEase()
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollFade(top: 3, bottom: 14)
            .onChange(of: engine.selectedID) { _, id in
                guard let id else { return }
                withAnimation(IslaMotion.snappy) { proxy.scrollTo(id) }
            }
        }
        .animation(IslaMotion.snappy, value: engine.answer?.title)
    }
}

// MARK: - Rows

private struct LauncherRow: View {
    let result: LauncherResult
    let selected: Bool
    let selection: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            LauncherIcon(icon: result.icon, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: result.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if !result.subtitle.isEmpty {
                    Text(verbatim: result.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if selected {
                HStack(spacing: 4) {
                    Text(result.actionName)
                    Image(systemName: "return")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .transition(.opacity.combined(with: .offset(x: 6)))
            } else {
                Text(result.kind.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .matchedGeometryEffect(id: "launcher-selection", in: selection)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// A calculation or a conversion, large, at the top.
private struct AnswerCard: View {
    let result: LauncherResult
    let selected: Bool

    var body: some View {
        HStack(spacing: 14) {
            LauncherIcon(icon: result.icon, size: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: result.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                Text(verbatim: result.title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Text(result.actionName)
                Image(systemName: "return")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(selected ? 0.8 : 0.4))
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(selected ? 0.13 : 0.07))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// With the field empty: the apps you open most, and a few things to try.
private struct LauncherHome: View {
    let engine: LauncherEngine
    let fill: (String) -> Void

    private var examples: [String] {
        [String(localized: "2^10 + 24"), String(localized: "10 km to mi"), String(localized: "100 usd to eur"),
         String(localized: "timer 25"), String(localized: "note call Ana")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                ForEach(Array(engine.favorites.enumerated()), id: \.element.id) { index, app in
                    Button { engine.open(app) } label: {
                        VStack(spacing: 6) {
                            LauncherIcon(icon: .app(app.url), size: 52)
                            Text(verbatim: app.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .frame(width: 84)
                        .padding(.vertical, 6)
                        .background(HoverPlate())
                    }
                    .buttonStyle(PressSqueeze())
                    .emerge(delay: 0.06 + Double(index) * 0.03, offset: CGSize(width: 0, height: -6))
                    .accessibilityLabel(Text(verbatim: app.name))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text("Try")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    // Lines up with the magnifying glass of the field above, not the panel's edge.
                    .padding(.leading, 12)
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    Button { fill(example) } label: {
                        Text(verbatim: example)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(PressSqueeze())
                    .emerge(delay: 0.16 + Double(index) * 0.03, offset: CGSize(width: 0, height: -4))
                }
            }
            .lineLimit(1)
        }
        // Centered in the room under the field, so the empty launcher never looks top-heavy.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

private struct HoverPlate: View {
    @State private var hovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(hovering ? 0.09 : 0))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Icons

struct LauncherIcon: View {
    let icon: LauncherResult.Icon
    let size: CGFloat

    var body: some View {
        Group {
            switch icon {
            case .app(let url):
                Image(nsImage: LauncherIcons.app(url))
                    .resizable()
                    .interpolation(.high)
            case .fileType(let type):
                Image(nsImage: LauncherIcons.type(type))
                    .resizable()
                    .interpolation(.high)
            case .symbol(let name, let color):
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .fill(color.gradient)
                    .overlay {
                        Image(systemName: name)
                            .font(.system(size: size * 0.48, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(size * 0.06)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Icons by app path or by file type. File icons come from the type alone, so no file is
/// ever opened or read to draw them.
@MainActor
enum LauncherIcons {
    private static var apps: [String: NSImage] = [:]
    private static var types: [String: NSImage] = [:]

    static func app(_ url: URL) -> NSImage {
        if let cached = apps[url.path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        if apps.count > 300 { apps.removeAll() }
        apps[url.path] = image
        return image
    }

    static func type(_ identifier: String) -> NSImage {
        if let cached = types[identifier] { return cached }
        let image = NSWorkspace.shared.icon(for: UTType(identifier) ?? .data)
        types[identifier] = image
        return image
    }
}
