//
//  AgentsView.swift
//  Isla
//
//  The AI tab: agents at work on this Mac, the local models in memory and
//  the AI apps that are open.
//

import SwiftUI

struct AgentsView: View {
    @Bindable var model: NotchViewModel
    private let monitor = AgentMonitor.shared
    private let prefs = Preferences.shared

    var body: some View {
        ZStack {
            if monitor.hasScanned {
                if monitor.isEmpty {
                    AgentsEmptyState()
                        .transition(.blurReplace.combined(with: .opacity))
                } else {
                    HStack(spacing: 12) {
                        AgentsListCard()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .emerge(delay: 0.06)
                        VStack(spacing: 10) {
                            if prefs.agentsLocalModels {
                                LocalModelsCard()
                                    .emerge(delay: 0.11)
                            }
                            if !monitor.apps.isEmpty || !prefs.agentsLocalModels {
                                AIAppsCard()
                                    .frame(height: prefs.agentsLocalModels ? 70 : nil)
                                    .emerge(delay: 0.16)
                            }
                        }
                        .frame(width: 236)
                    }
                    .transition(.blurReplace.combined(with: .opacity))
                }
            }
        }
        .animation(IslaMotion.content, value: monitor.isEmpty)
        .animation(IslaMotion.content, value: monitor.hasScanned)
        .onAppear { monitor.tabAppeared() }
        .onDisappear { monitor.tabDisappeared() }
    }
}

// MARK: - Agents

private struct AgentsListCard: View {
    private let monitor = AgentMonitor.shared

    var body: some View {
        let sessions = monitor.sessions
        let working = sessions.filter { $0.state == .working }.count
        let attention = sessions.filter { $0.state == .needsYou }.count

        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(title: "Agents", symbol: "sparkles", tint: .orange) {
                    HStack(spacing: 6) {
                        if attention > 0 {
                            CountChip(count: attention, state: .needsYou)
                        }
                        if working > 0 {
                            CountChip(count: working, state: .working)
                        }
                        Text("\(sessions.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .contentTransition(.numericText(value: Double(sessions.count)))
                    }
                    .animation(IslaMotion.snappy, value: working)
                    .animation(IslaMotion.snappy, value: attention)
                }
                .padding(.horizontal, 4)

                if sessions.isEmpty {
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("No agents running")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Start one in Terminal or in its app and it shows up here.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.blurReplace)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 2) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                AgentRow(session: session)
                                    .emerge(delay: 0.1 + Double(min(index, 5)) * 0.04, offset: CGSize(width: 0, height: -6))
                                    .transition(.asymmetric(
                                        insertion: AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96, anchor: .top)),
                                        removal: AnyTransition(.blurReplace).combined(with: .opacity)))
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollFade()
                }
            }
        }
    }
}

private struct CountChip: View {
    let count: Int
    let state: AgentState

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(state.tint).frame(width: 5, height: 5)
            Text("\(count)")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .foregroundStyle(state.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(state.tint.opacity(0.14)))
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

private struct AgentRow: View {
    let session: AgentSession
    @State private var hovering = false
    private let monitor = AgentMonitor.shared

    var body: some View {
        HStack(spacing: 10) {
            AgentGlyph(tool: session.tool, icon: monitor.iconForSession(session), size: 30,
                       working: session.state == .working)
                .padding(.leading, 1)

            VStack(alignment: .leading, spacing: 2) {
                // A long title keeps its room: the badge shrinks to the model, since the
                // glyph already says which tool it is.
                ViewThatFits(in: .horizontal) {
                    titleLine(badge: [session.tool.name, session.model].compactMap { $0 }.joined(separator: " · "))
                    titleLine(badge: session.model ?? session.tool.name)
                }
                detailLine
                stepLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .trailing) {
                if hovering {
                    actions
                        .transition(.blurReplace.combined(with: .opacity))
                } else {
                    status
                        .transition(.blurReplace.combined(with: .opacity))
                }
            }
            .animation(IslaMotion.snappy, value: hovering)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(minHeight: 46)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(hovering ? 0.08 : 0))
        }
        .overlay(alignment: .leading) {
            // A thin bar in the state color marks agents that need attention.
            if session.state == .needsYou {
                Capsule()
                    .fill(session.state.tint)
                    .frame(width: 2.5, height: 22)
                    .offset(x: -2)
                    .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture { monitor.bringToFront(session) }
        // One element for VoiceOver: who, what state, where, and the row's actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { monitor.bringToFront(session) }
        .accessibilityAction(named: Text("Show in Finder")) { monitor.showFolder(session) }
        .accessibilityAction(named: Text("Copy folder path")) { monitor.copyFolder(session) }
        .animation(IslaMotion.snappy, value: hovering)
        .animation(IslaMotion.content, value: session.state)
        .help(session.folder ?? session.tool.name)
    }

    /// Folder, host app, start time and usage limit. Drops the least useful parts when
    /// the row is narrow instead of cutting the folder.
    private var accessibilitySummary: String {
        [session.displayTitle, session.tool.name, session.model, session.state.titleString,
         session.step?.text, session.project.map { String(localized: "in \($0)") }]
            .compactMap { $0 }.joined(separator: ", ")
    }

    private func titleLine(badge: String) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: session.displayTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
            if session.title != nil || session.project != nil {
                Text(verbatim: badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(session.tool.tint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(session.tool.tint.opacity(0.16)))
                    .fixedSize()
                    .help([session.tool.name, session.contextSummary].compactMap { $0 }.joined(separator: " · "))
            }
        }
    }

    private var detailLine: some View {
        ViewThatFits(in: .horizontal) {
            detailParts(folder: session.shortFolder, host: true)
            detailParts(folder: session.project ?? session.shortFolder, host: true)
            detailParts(folder: session.project ?? session.shortFolder, host: false)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }

    private func detailParts(folder: String?, host showsHost: Bool) -> some View {
        HStack(spacing: 4) {
            if let folder {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8.5))
                Text(verbatim: folder)
                    .lineLimit(1)
                    .fixedSize()
            }
            if showsHost, let host = session.hostName, session.tool.kind == .cli {
                Text(verbatim: "·")
                Text("in \(host)")
                    .lineLimit(1)
                    .fixedSize()
            }
            Text(verbatim: "·")
            Image(systemName: "clock")
                .font(.system(size: 8.5))
            Text(session.started, format: .dateTime.hour().minute())
                .monospacedDigit()
                .fixedSize()
            if let used = session.limitUsed, let window = session.limitWindow {
                Text(verbatim: "·")
                Text("\(AgentDuration.window(minutes: window)) limit: \(Int(used.rounded()))%")
                    .foregroundStyle(used >= 80 ? AgentState.needsYou.tint : .secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .help(String(localized: "Share of the account's usage limit already used"))
            }
        }
    }

    @ViewBuilder private var stepLine: some View {
        if session.state == .working || session.state == .needsYou, let step = session.step {
            HStack(spacing: 4) {
                Image(systemName: step.symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                    .frame(width: 11)
                Text(verbatim: step.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(session.state == .needsYou ? session.state.tint : .white.opacity(0.62))
            .id(step.text)
            .transition(.blurReplace.combined(with: .opacity))
        }
    }

    private var status: some View {
        VStack(alignment: .trailing, spacing: 5) {
            AgentStatePill(state: session.state)
            HStack(spacing: 6) {
                ActivitySparkline(values: session.history, tint: session.state == .working ? session.state.tint : .white.opacity(0.45))
                    .frame(width: 40, height: 12)
                TimelineView(.periodic(from: .now, by: 20)) { context in
                    Text(verbatim: AgentDuration.label(since: session.stateSince, now: context.date))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
        }
        .help(timeHelp)
    }

    private var timeHelp: String {
        let started = session.started.formatted(date: .omitted, time: .shortened)
        switch session.state {
        case .working:
            return String(localized: "Working since \(session.stateSince.formatted(date: .omitted, time: .shortened)) · running since \(started)")
        case .idle:
            return String(localized: "Running since \(started)")
        case .waiting, .needsYou:
            return String(localized: "Waiting since \(session.stateSince.formatted(date: .omitted, time: .shortened)) · running since \(started)")
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if session.hostPID != nil {
                Button { monitor.bringToFront(session) } label: { Image(systemName: "macwindow") }
                    .buttonStyle(NotchIconButtonStyle(size: 26))
                    .help(String(localized: "Show \(session.hostName ?? session.tool.name)"))
            }
            if session.folder != nil {
                Button { monitor.showFolder(session) } label: { Image(systemName: "folder") }
                    .buttonStyle(NotchIconButtonStyle(size: 26))
                    .help(String(localized: "Show in Finder"))
                Button {
                    monitor.copyFolder(session)
                    Haptics.tap()
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(NotchIconButtonStyle(size: 26))
                    .help(String(localized: "Copy folder path"))
            }
        }
    }
}

// MARK: - Local models

private struct LocalModelsCard: View {
    private let monitor = AgentMonitor.shared

    var body: some View {
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(title: "Local models", symbol: "cpu", tint: .purple)
                if !monitor.servers.isEmpty {
                    // Which model servers are running, under the title so it never gets cut.
                    HStack(spacing: 4) {
                        ForEach(monitor.servers) { server in
                            ServerDot(server: server)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.top, -2)
                }
                if monitor.models.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Spacer(minLength: 0)
                        Text(monitor.servers.isEmpty ? "No model loaded" : "Ready, no model loaded")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Models you load in Ollama or LM Studio appear here with the memory they use.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .transition(.blurReplace)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(monitor.models) { model in
                                LocalModelRow(model: model)
                                    .transition(AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96, anchor: .top)))
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollFade()
                }
            }
        }
    }
}

private struct ServerDot: View {
    let server: LocalServer

    var body: some View {
        let tool = AgentCatalog.tool(id: server.id) ?? AgentCatalog.ollama
        HStack(spacing: 3) {
            Circle().fill(AgentState.working.tint).frame(width: 5, height: 5)
            Text(verbatim: server.name)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(Capsule().fill(tool.tint.opacity(0.16)))
        .fixedSize()
        .help(server.version.map { "\(server.name) \($0)" } ?? server.name)
    }
}

private struct LocalModelRow: View {
    let model: LocalModel
    private static let memory = Double(ProcessInfo.processInfo.physicalMemory)

    var body: some View {
        let tool = AgentCatalog.tool(id: model.serverID) ?? AgentCatalog.ollama
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                AgentGlyph(tool: tool, size: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: shortName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(verbatim: model.detail ?? AgentCatalog.tool(id: model.serverID)?.name ?? "")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(model.context.map { String(localized: "\($0.formatted(.number.notation(.compactName))) context") } ?? "")
                }
                Spacer(minLength: 2)
                if let bytes = model.bytes {
                    Text(verbatim: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize()
                }
            }
            if let bytes = model.bytes {
                GeometryReader { proxy in
                    let share = min(1, Double(bytes) / max(1, Self.memory))
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(tool.gradient)
                            .frame(width: max(3, proxy.size.width * share))
                    }
                }
                .frame(height: 3)
                .help(String(localized: "\(Int((Double(bytes) / max(1, Self.memory) * 100).rounded()))% of this Mac's memory"))
            }
            if let expires = model.expires {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    let remaining = expires.timeIntervalSince(context.date)
                    Text(remaining > 60 ? "Unloads in \(AgentDuration.label(since: context.date.addingTimeInterval(-remaining), now: context.date))"
                                        : "Unloading soon")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// "google/gemma-4-12b-qat" → "gemma-4-12b-qat"; "llama3:latest" → "llama3".
    private var shortName: String {
        var name = model.name.split(separator: "/").last.map(String.init) ?? model.name
        if name.hasSuffix(":latest") { name.removeLast(":latest".count) }
        return name
    }
}

// MARK: - Apps

private struct AIAppsCard: View {
    private let monitor = AgentMonitor.shared

    var body: some View {
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "AI apps", symbol: "macwindow.on.rectangle", tint: .teal)
                if monitor.apps.isEmpty {
                    Text("No AI apps open")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(monitor.apps) { app in
                                AppIconButton(app: app)
                                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct AppIconButton: View {
    let app: AIApp
    @State private var hovering = false

    var body: some View {
        Button { AgentMonitor.shared.activate(app) } label: {
            Group {
                if let icon = AgentMonitor.shared.icon(bundleID: app.bundleID) {
                    Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill").font(.system(size: 20))
                }
            }
            .frame(width: 30, height: 30)
            .scaleEffect(hovering ? 1.12 : 1, anchor: .bottom)
            .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: 4, y: 2)
        }
        .buttonStyle(PressSqueeze())
        .onHover { hovering = $0 }
        .animation(IslaMotion.snappy, value: hovering)
        .help(app.name)
    }
}

// MARK: - Empty state

private struct AgentsEmptyState: View {
    var body: some View {
        HStack(spacing: 26) {
            AgentOrbit()
                .frame(width: 112, height: 112)
                .emerge(delay: 0.06)

            VStack(alignment: .leading, spacing: 7) {
                Text("No agents at work")
                    .font(.system(size: 16, weight: .bold))
                    .emerge(delay: 0.1)
                Text("Start a coding agent in Terminal or in its app, or load a local model. Isla shows which folder it works in, since when and whether it is working or waiting for you.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380, alignment: .leading)
                    .emerge(delay: 0.14)
                HStack(spacing: 5) {
                    ForEach(Array(AgentCatalog.showcase.enumerated()), id: \.element.id) { index, tool in
                        HStack(spacing: 4) {
                            AgentGlyph(tool: tool, size: 14)
                            Text(verbatim: tool.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize()
                        }
                        .padding(.leading, 3)
                        .padding(.trailing, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.07)))
                        .emerge(delay: 0.2 + Double(index) * 0.04, offset: CGSize(width: 0, height: -5))
                    }
                }
                .padding(.top, 3)
                Text("No permissions needed. Nothing leaves your Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .emerge(delay: 0.42)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A calm orbit: the tools' colors circling a spark, waiting for something to do.
private struct AgentOrbit: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 1.2 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                ZStack {
                    ForEach(0..<2, id: \.self) { ring in
                        Ellipse()
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                            .frame(width: size.width * (ring == 0 ? 1 : 0.68), height: size.height * (ring == 0 ? 0.5 : 0.36))
                            .rotationEffect(.degrees(ring == 0 ? -18 : 24))
                    }
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .center, startRadius: 2, endRadius: 40))
                        .frame(width: 80, height: 80)
                        .scaleEffect(1 + 0.06 * sin(t * 1.4))
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .symbolRenderingMode(.hierarchical)

                    ForEach(Array(AgentCatalog.showcase.prefix(4).enumerated()), id: \.element.id) { index, tool in
                        let outer = index % 2 == 0
                        let speed = outer ? 0.55 : -0.8
                        let angle = t * speed + Double(index) * (.pi / 2)
                        let radiusX = size.width * (outer ? 0.5 : 0.34)
                        let radiusY = size.height * (outer ? 0.25 : 0.18)
                        let tilt = (outer ? -18.0 : 24.0) * .pi / 180
                        let x = cos(angle) * radiusX, y = sin(angle) * radiusY
                        let point = CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt),
                                            y: center.y + x * sin(tilt) + y * cos(tilt))
                        let depth = (sin(angle) + 1) / 2
                        Circle()
                            .fill(tool.gradient)
                            .frame(width: 7 + 4 * depth, height: 7 + 4 * depth)
                            .shadow(color: tool.tint.opacity(0.7), radius: 4)
                            .opacity(0.55 + 0.45 * depth)
                            .position(point)
                            .zIndex(depth)
                    }
                }
            }
        }
    }
}
