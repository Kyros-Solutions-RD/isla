//
//  AgentMonitor.swift
//  Isla
//
//  Finds the AI agents running on this Mac and follows them: which tool,
//  which folder, since when, and whether it is working or waiting. It also
//  lists the local models loaded in Ollama or LM Studio and the AI apps that
//  are open. No permission is needed: Isla only looks at the user's own
//  processes and at files the agents keep in the home folder.
//

import AppKit
import SwiftUI

enum AgentState: Equatable {
    case working
    case waiting
    case needsYou
    /// An editor that is open but quiet.
    case idle
    /// The process is gone; kept for a few minutes so the user sees it finished.
    case ended

    var title: LocalizedStringKey {
        switch self {
        case .working: "Working"
        case .waiting: "Waiting"
        case .needsYou: "Needs you"
        case .idle: "Idle"
        case .ended: "Ended"
        }
    }

    /// The state as plain text, for VoiceOver.
    var titleString: String {
        switch self {
        case .working: String(localized: "Working")
        case .waiting: String(localized: "Waiting")
        case .needsYou: String(localized: "Needs you")
        case .idle: String(localized: "Idle")
        case .ended: String(localized: "Ended")
        }
    }

    var tint: Color {
        switch self {
        case .working: Color(red: 0.36, green: 0.86, blue: 0.52)
        case .waiting: Color(red: 1.0, green: 0.8, blue: 0.32)
        case .needsYou: Color(red: 1.0, green: 0.55, blue: 0.3)
        case .idle: Color.white.opacity(0.6)
        case .ended: Color.white.opacity(0.5)
        }
    }

    var symbol: String {
        switch self {
        case .working: "bolt.fill"
        case .waiting: "hourglass"
        case .needsYou: "hand.raised.fill"
        case .idle: "moon.fill"
        case .ended: "checkmark.circle"
        }
    }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    let pid: pid_t
    let tool: AgentTool
    var title: String?
    var folder: String?
    var started: Date
    var state: AgentState
    var stateSince: Date
    var step: AgentStep?
    var cpu: Double
    var memory: UInt64
    var history: [Double]
    var hostName: String?
    var hostPID: pid_t?
    var hostBundleID: String?
    /// The model the session talks to, already formatted ("Opus 5.5").
    var model: String?
    /// Share of the account's usage limit already used, and the window in minutes (Codex).
    var limitUsed: Double?
    var limitWindow: Int?
    /// Tokens in the conversation the model saw last, and its window when the agent says.
    var contextTokens: Int?
    var contextWindow: Int?
    /// When the process went away (ended sessions only).
    var endedAt: Date? = nil

    /// "Context: 128K tokens", or "Context: 128K of 272K tokens (47%)".
    var contextSummary: String? {
        guard let tokens = contextTokens else { return nil }
        let used = tokens.formatted(.number.notation(.compactName))
        if let window = contextWindow, window > 0 {
            let share = Int((Double(tokens) / Double(window) * 100).rounded())
            return String(localized: "Context: \(used) of \(window.formatted(.number.notation(.compactName))) tokens (\(share)%)")
        }
        return String(localized: "Context: \(used) tokens")
    }

    /// The project the agent works on.
    var project: String? {
        guard let folder, folder != "/", folder != NSHomeDirectory() else { return nil }
        return (folder as NSString).lastPathComponent
    }

    var displayTitle: String { (title ?? project ?? tool.name).readableName }

    /// The project and the folder it sits in: "MACBOOK › NOTCHY CLONE".
    var shortFolder: String? {
        guard let folder, folder != "/" else { return nil }
        if folder == NSHomeDirectory() { return "~" }
        let parts = folder.split(separator: "/").suffix(2)
        return parts.joined(separator: " › ")
    }

    /// The folder with the home folder shortened to "~".
    var displayFolder: String? {
        guard let folder, folder != "/" else { return nil }
        let home = NSHomeDirectory()
        return folder.hasPrefix(home) ? "~" + folder.dropFirst(home.count) : folder
    }
}

struct AIApp: Identifiable, Equatable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let pid: pid_t
}

// MARK: - Monitor

@Observable
@MainActor
final class AgentMonitor {
    static let shared = AgentMonitor()

    private(set) var sessions: [AgentSession] = []
    /// Sessions whose process ended in the last few minutes, newest first.
    private(set) var ended: [AgentSession] = []
    private(set) var apps: [AIApp] = []
    private(set) var models: [LocalModel] = []
    private(set) var servers: [LocalServer] = []
    private(set) var hasScanned = false

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var scanning = false
    @ObservationIgnored private var tick = 0
    @ObservationIgnored private var visibleViews = 0
    @ObservationIgnored private var cpuBook: [pid_t: UInt64] = [:]
    @ObservationIgnored private var lastSample: Date?
    @ObservationIgnored private var lowStreak: [String: Int] = [:]
    @ObservationIgnored private var lastModelProbe: Date = .distantPast
    @ObservationIgnored private var lastCommandLineProbe: Date = .distantPast
    @ObservationIgnored private var cachedCommandLineModels: [LocalModel] = []
    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    @ObservationIgnored private var localProcesses: Set<String> = []

    private static let historyLength = 26

    private init() {}

    var workingSessions: [AgentSession] { sessions.filter { $0.state == .working } }
    /// Agents that are working or waiting on the user's answer: what the notch ears show.
    var activeSessions: [AgentSession] {
        sessions.filter { $0.state == .needsYou } + sessions.filter { $0.state == .working }
    }
    var hasActiveAgents: Bool { sessions.contains { $0.state == .working || $0.state == .needsYou } }
    var isEmpty: Bool { sessions.isEmpty && ended.isEmpty && models.isEmpty && apps.isEmpty && servers.isEmpty }

    private static let endedLifetime: TimeInterval = 10 * 60

    #if DEBUG
    /// Hides everything to preview the empty state (`isla-dev://demo/agents-empty`). Memory only.
    @ObservationIgnored private var demoHidesAll = false
    /// Keeps a sample set on screen (`isla-dev://demo/agents-sample`), for the website's screenshots.
    @ObservationIgnored private var demoFrozen = false
    #endif

    // MARK: Lifecycle

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.step()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Called by the AI tab so it refreshes faster and reads steps and models while visible.
    func tabAppeared() {
        visibleViews += 1
        Task { await scan(full: true) }
    }

    func tabDisappeared() {
        visibleViews = max(0, visibleViews - 1)
    }

    func refreshNow() {
        Task { await scan(full: visibleViews > 0) }
    }

    private func step() async {
        tick &+= 1
        let prefs = Preferences.shared
        let visible = visibleViews > 0
        let followsInBackground = prefs.activityAgents || prefs.agentsNotifyFinished
        if visible || (followsInBackground && tick % 2 == 0) {
            await scan(full: visible)
        } else if !followsInBackground && !visible && !sessions.isEmpty && !prefs.visibleTabs.contains(.agents) {
            // Nothing shows agents any more: forget them so the notch stays quiet.
            sessions = []
        }
    }

    // MARK: Scanning

    private func scan(full: Bool) async {
        guard !scanning else { return }
        scanning = true
        defer { scanning = false }

        let prefs = Preferences.shared
        let request = AgentScanner.Request(
            customCommands: prefs.agentsCustomCommands,
            wantsSteps: prefs.agentsShowSteps,
            apps: NSWorkspace.shared.runningApplications.compactMap { app in
                guard let bundle = app.bundleIdentifier else { return nil }
                return AgentScanner.RunningApp(pid: app.processIdentifier, bundleID: bundle, name: app.localizedName ?? bundle,
                                               isRegular: app.activationPolicy == .regular)
            },
            previousCPU: cpuBook,
            previousSample: lastSample,
            knownModels: Set(sessions.filter { $0.model != nil }.map(\.pid)))

        let result = await Task.detached(priority: .utility) { AgentScanner.scan(request) }.value
        cpuBook = result.cpuBook
        lastSample = result.date
        localProcesses = result.localServerProcesses
        apply(result, apps: request.apps)
        hasScanned = true

        // Every few seconds while the tab is open; now and then otherwise, so it opens up to date.
        let modelInterval: TimeInterval = full ? 4.5 : 20
        if prefs.agentsLocalModels && Date().timeIntervalSince(lastModelProbe) > modelInterval {
            lastModelProbe = Date()
            await refreshModels(lmStudioOpen: result.localServerProcesses.contains(AgentCatalog.lmStudio.id), allowCommandLine: full)
        } else if !prefs.agentsLocalModels, !models.isEmpty || !servers.isEmpty {
            models = []
            servers = []
        }
    }

    private func apply(_ result: AgentScanner.Result, apps running: [AgentScanner.RunningApp]) {
        #if DEBUG
        if demoHidesAll {
            sessions = []; apps = []; models = []; servers = []
            return
        }
        if demoFrozen { return }
        #endif
        let now = result.date
        let previous = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var next: [AgentSession] = []

        for raw in result.agents {
            let id = "\(raw.toolID)-\(raw.pid)"
            guard let tool = AgentCatalog.tool(id: raw.toolID) else { continue }
            let old = previous[id]
            var history = old?.history ?? []
            history.append(raw.cpuPercent)
            if history.count > Self.historyLength { history.removeFirst(history.count - Self.historyLength) }

            let state = decideState(id: id, raw: raw, tool: tool, previous: old?.state)
            var since = old?.state == state ? (old?.stateSince ?? now) : now
            if let changed = raw.session?.statusChanged, raw.session?.status != nil, old == nil || old?.state != state {
                since = min(changed, now)
            }

            let host = hostApp(for: raw, running: running)
            next.append(AgentSession(
                id: id, pid: raw.pid, tool: tool,
                title: raw.session?.name,
                folder: raw.folder,
                started: raw.session?.started ?? raw.started,
                state: state, stateSince: since,
                step: Self.step(for: state, raw: raw, previous: old),
                cpu: raw.cpuPercent, memory: raw.memory, history: history,
                hostName: host?.name, hostPID: host?.pid, hostBundleID: host?.bundleID,
                model: raw.model.map(AgentModelName.display) ?? old?.model,
                limitUsed: raw.limitUsed ?? old?.limitUsed,
                limitWindow: raw.limitWindow ?? old?.limitWindow,
                contextTokens: raw.contextTokens ?? old?.contextTokens,
                contextWindow: raw.contextWindow ?? old?.contextWindow))
        }

        next.sort { lhs, rhs in
            let order: (AgentState) -> Int = { [.needsYou: 0, .working: 1, .waiting: 2, .idle: 3][$0] ?? 4 }
            if order(lhs.state) != order(rhs.state) { return order(lhs.state) < order(rhs.state) }
            return lhs.started > rhs.started
        }

        announceChanges(from: previous, to: next, now: now)
        let nextEnded = endedSessions(after: next, now: now)

        let structural = next.map(\.id) != sessions.map(\.id) || next.map(\.state) != sessions.map(\.state)
            || nextEnded.map(\.id) != ended.map(\.id)
        // Editors already have their own row, so they are not repeated among the apps.
        let editorPIDs = Set(next.filter { $0.tool.kind == .editor }.map(\.pid))
        let nextApps = running
            .filter { $0.isRegular && AgentCatalog.isAIApp(bundleIdentifier: $0.bundleID) && !editorPIDs.contains($0.pid) }
            .map { AIApp(bundleID: $0.bundleID, name: $0.name, pid: $0.pid) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        if structural || nextApps != apps {
            withAnimation(IslaMotion.content) {
                sessions = next
                ended = nextEnded
                apps = nextApps
            }
        } else {
            sessions = next
            ended = nextEnded
        }
        lowStreak = lowStreak.filter { key, _ in next.contains { $0.id == key } }
    }

    private func decideState(id: String, raw: AgentScanner.RawAgent, tool: AgentTool, previous: AgentState?) -> AgentState {
        if raw.step?.asksUser == true, raw.session?.status.map(AgentSessionFile.isBusy) != false {
            return .needsYou
        }
        if let session = raw.session, let status = session.status?.lowercased() {
            if session.needsUser { return .needsYou }
            if AgentSessionFile.isBusy(status) { return .working }
            return .waiting
        }
        // No status to read: judge by CPU, with a little patience before calling it quiet.
        let threshold = tool.kind == .editor ? 22.0 : 3.0
        if raw.cpuPercent >= threshold {
            lowStreak[id] = 0
            return .working
        }
        let streak = (lowStreak[id] ?? 0) + 1
        lowStreak[id] = streak
        if previous == .working && streak < 3 { return .working }
        return tool.kind == .editor ? .idle : .waiting
    }

    /// While waiting on the user, the reason comes first and the tool it is about after it.
    private static func step(for state: AgentState, raw: AgentScanner.RawAgent, previous: AgentSession?) -> AgentStep? {
        if state == .needsYou, var waiting = raw.session?.waitingStep {
            if let detail = raw.step ?? previous?.step, !detail.asksUser { waiting.text += " · " + detail.text }
            return waiting
        }
        return raw.step ?? (state == .working ? previous?.step : nil)
    }

    private func hostApp(for raw: AgentScanner.RawAgent, running: [AgentScanner.RunningApp]) -> AgentScanner.RunningApp? {
        let byPID = Dictionary(running.filter(\.isRegular).map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        if let own = byPID[raw.pid] { return own }
        return raw.ancestors.lazy.compactMap { byPID[$0] }.first
    }

    /// A short moment in the notch when an agent finishes or stops to ask something.
    private func announceChanges(from previous: [String: AgentSession], to next: [AgentSession], now: Date) {
        guard Preferences.shared.agentsNotifyFinished, hasScanned else { return }
        for session in next {
            guard let old = previous[session.id], old.state == .working, session.state != .working else { continue }
            // Asking for something is worth a moment right away; finishing only after real work.
            guard session.tool.kind == .cli,
                  session.state == .needsYou || now.timeIntervalSince(old.stateSince) >= 8 else { continue }
            postMoment(for: session, needsYou: session.state == .needsYou)
            return
        }
    }

    private func postMoment(for session: AgentSession, needsYou: Bool) {
        LiveActivityCenter.shared.post(.agentFinished(toolID: session.tool.id,
                                                      title: (session.project ?? session.tool.name).readableName,
                                                      needsYou: needsYou),
                                       duration: 5)
        let sound = Preferences.shared.agentsSound
        if !sound.isEmpty { NSSound(named: NSSound.Name(sound))?.play() }
    }

    /// Sessions whose process just went away stay a few minutes, dimmed, so a run that
    /// finished on its own (a one-shot command, a closed terminal) does not simply vanish.
    private func endedSessions(after next: [AgentSession], now: Date) -> [AgentSession] {
        let alive = Set(next.map(\.id))
        var result = ended.filter { session in
            !alive.contains(session.id) && now.timeIntervalSince(session.endedAt ?? now) < Self.endedLifetime
        }
        guard hasScanned else { return result }
        for old in sessions where !alive.contains(old.id) && old.tool.kind == .cli {
            var gone = old
            gone.state = .ended
            gone.stateSince = now
            gone.endedAt = now
            gone.step = nil
            gone.cpu = 0
            result.insert(gone, at: 0)
            if old.state == .working, now.timeIntervalSince(old.stateSince) >= 8, Preferences.shared.agentsNotifyFinished {
                postMoment(for: old, needsYou: false)
            }
        }
        // A session that restarted under a new process is not "ended".
        result.removeAll { gone in
            next.contains { $0.tool == gone.tool && $0.folder == gone.folder && $0.title == gone.title }
        }
        return Array(result.prefix(4))
    }

    // MARK: Local models

    private func refreshModels(lmStudioOpen: Bool, allowCommandLine: Bool) async {
        async let ollama = LocalModelProbe.ollama()
        async let lmServer = LocalModelProbe.lmStudioServer()
        let (ollamaResult, lmServerModels) = await (ollama, lmServer)

        var nextServers: [LocalServer] = []
        var nextModels: [LocalModel] = []
        if let ollamaResult {
            nextServers.append(ollamaResult.server)
            nextModels += ollamaResult.models
        } else if localProcesses.contains(AgentCatalog.ollama.id) {
            nextServers.append(LocalServer(id: AgentCatalog.ollama.id, name: AgentCatalog.ollama.name, version: nil))
        }

        if let lmServerModels {
            nextServers.append(LocalServer(id: AgentCatalog.lmStudio.id, name: lmStudioName, version: nil))
            nextModels += lmServerModels
        } else if lmStudioOpen {
            nextServers.append(LocalServer(id: AgentCatalog.lmStudio.id, name: lmStudioName, version: nil))
            // The command line tool is slower than the server: ask it every few seconds at most.
            if allowCommandLine && Date().timeIntervalSince(lastCommandLineProbe) > 9 {
                lastCommandLineProbe = Date()
                cachedCommandLineModels = await LocalModelProbe.lmStudioCommandLine() ?? []
            }
            nextModels += cachedCommandLineModels
        }
        for tool in [AgentCatalog.llamaCpp, AgentCatalog.mlx] where localProcesses.contains(tool.id) {
            nextServers.append(LocalServer(id: tool.id, name: tool.name, version: nil))
        }

        #if DEBUG
        if demoHidesAll || demoFrozen { return }
        #endif
        if nextModels != models || nextServers != servers {
            withAnimation(IslaMotion.content) {
                models = nextModels
                servers = nextServers
            }
        }
    }

    /// LM Studio's app has been renamed over time; show whatever the installed one is called.
    private var lmStudioName: String {
        NSWorkspace.shared.runningApplications.first { AgentCatalog.isLMStudio(bundleIdentifier: $0.bundleIdentifier) }?
            .localizedName ?? AgentCatalog.lmStudio.name
    }

    // MARK: Icons and actions

    func icon(bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = iconCache[bundleID] { return cached }
        let icon = NSWorkspace.shared.appIcon(bundleIdentifier: bundleID)
        iconCache[bundleID] = icon
        return icon
    }

    func bringToFront(_ session: AgentSession) {
        if let pid = session.hostPID, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        } else if let folder = session.folder {
            NSWorkspace.shared.open(URL(fileURLWithPath: folder, isDirectory: true))
        }
    }

    func showFolder(_ session: AgentSession) {
        guard let folder = session.folder else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: folder, isDirectory: true))
    }

    func copyFolder(_ session: AgentSession) {
        guard let folder = session.folder else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder, forType: .string)
    }

    /// The app behind a model server (LM Studio, Ollama), if it is installed as an app.
    private func appURL(for server: LocalServer) -> URL? {
        let match: (String?) -> Bool = server.id == AgentCatalog.lmStudio.id ? AgentCatalog.isLMStudio : AgentCatalog.isOllama
        return NSWorkspace.shared.runningApplications.first { match($0.bundleIdentifier) }?.bundleURL
    }

    func canOpen(_ server: LocalServer) -> Bool { appURL(for: server) != nil }

    /// Brings the server's app forward, so a model can be loaded there.
    func open(_ server: LocalServer) {
        guard let url = appURL(for: server) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func activate(_ app: AIApp) {
        NSRunningApplication(processIdentifier: app.pid)?.activate()
    }

    #if DEBUG
    /// Previews for the AI tab and its notch moments. Nothing is saved.
    func runDemo(_ name: String) {
        let tool = sessions.first?.tool ?? AgentCatalog.claudeCode
        let title = sessions.first?.project?.readableName ?? "Isla"
        switch name {
        case "agent-done":
            LiveActivityCenter.shared.post(.agentFinished(toolID: tool.id, title: title, needsYou: false), duration: 6)
        case "agent-needs":
            LiveActivityCenter.shared.post(.agentFinished(toolID: tool.id, title: title, needsYou: true), duration: 6)
        case "agents-empty":
            withAnimation(IslaMotion.content) {
                demoHidesAll = true
                sessions = []; apps = []; models = []; servers = []
            }
        case "agents-live":
            demoHidesAll = false
            demoFrozen = false
            refreshNow()
        case "agents-sample", "agents-sample-working":
            applySample(asksUser: name == "agents-sample")
        default:
            break
        }
    }

    /// Fictional agents, models and apps for screenshots: made-up projects, nothing read from disk.
    private func applySample(asksUser: Bool) {
        demoFrozen = true
        let now = Date()
        let home = NSHomeDirectory()
        func wave(_ peak: Double, _ phase: Double) -> [Double] {
            (0..<26).map { max(0, peak * (0.55 + 0.45 * sin(Double($0) * 0.6 + phase))) }
        }
        let codex = AgentSession(
            id: "sample-codex", pid: 0, tool: AgentCatalog.codex, title: nil,
            folder: home + "/Proyectos/isla-web", started: now.addingTimeInterval(-42 * 60),
            state: .working, stateSince: now.addingTimeInterval(-3 * 60),
            step: AgentStep(text: String(localized: "Editing \("hero.css")"), symbol: "pencil"),
            cpu: 18, memory: 210_000_000, history: wave(24, 0), hostName: "Terminal", hostPID: nil, hostBundleID: nil,
            model: "GPT-5.5-Codex", limitUsed: 23, limitWindow: 300, contextTokens: 84_000, contextWindow: 272_000)
        let gemini = AgentSession(
            id: "sample-gemini", pid: 0, tool: AgentCatalog.gemini, title: nil,
            folder: home + "/Proyectos/kyros-finance", started: now.addingTimeInterval(-18 * 60),
            state: asksUser ? .needsYou : .waiting, stateSince: now.addingTimeInterval(-40),
            step: asksUser ? AgentStep(text: String(localized: "Waiting for your permission") + " · " + String(localized: "Running \("npm run migrate")"),
                                       symbol: "hand.raised.fill", asksUser: true) : nil,
            cpu: 0.4, memory: 160_000_000, history: wave(9, 2), hostName: "Ghostty", hostPID: nil, hostBundleID: nil,
            model: "Gemini 3 Pro")
        let aider = AgentSession(
            id: "sample-aider", pid: 0, tool: AgentCatalog.cli.first { $0.id == "aider" } ?? AgentCatalog.gemini, title: nil,
            folder: home + "/Proyectos/colmado-api", started: now.addingTimeInterval(-2 * 3600),
            state: .waiting, stateSince: now.addingTimeInterval(-12 * 60),
            step: nil, cpu: 0.2, memory: 120_000_000, history: wave(4, 4), hostName: "Terminal", hostPID: nil, hostBundleID: nil,
            model: "Qwen3 Coder")
        let antigravity = AgentSession(
            id: "sample-antigravity", pid: 0, tool: AgentCatalog.editors[0], title: nil,
            folder: home + "/Proyectos/malecon-app", started: now.addingTimeInterval(-3 * 3600),
            state: .idle, stateSince: now.addingTimeInterval(-25 * 60),
            step: nil, cpu: 3, memory: 900_000_000, history: wave(6, 1), hostName: "Antigravity", hostPID: nil, hostBundleID: nil)
        withAnimation(IslaMotion.content) {
            sessions = [gemini, codex, aider, antigravity].sorted { lhs, rhs in
                let order: (AgentState) -> Int = { [.needsYou: 0, .working: 1, .waiting: 2, .idle: 3][$0] ?? 4 }
                return order(lhs.state) < order(rhs.state)
            }
            ended = []
            apps = [AIApp(bundleID: "com.openai.codex", name: "ChatGPT", pid: 0),
                    AIApp(bundleID: "com.microsoft.m365copilot", name: "Copilot", pid: 0)]
            servers = [LocalServer(id: AgentCatalog.ollama.id, name: AgentCatalog.ollama.name, version: "0.13.0"),
                       LocalServer(id: AgentCatalog.lmStudio.id, name: AgentCatalog.lmStudio.name, version: nil)]
            models = [
                LocalModel(id: "sample-qwen", serverID: AgentCatalog.ollama.id, name: "qwen3-coder:30b", detail: "30.5B · Q4_K_M",
                           bytes: 18_600_000_000, gpuBytes: 18_600_000_000, expires: now.addingTimeInterval(4 * 60 + 20), context: 32_768),
                LocalModel(id: "sample-gemma", serverID: AgentCatalog.lmStudio.id, name: "google/gemma-4-12b-qat", detail: "gemma4 · Q4_0",
                           bytes: 7_150_000_000, gpuBytes: nil, expires: nil, context: 8_192),
            ]
        }
        hasScanned = true
    }

    /// Prints what the monitor sees (`ISLA_AGENTS_REPORT=1`), for checking detection.
    func report() async {
        visibleViews = 1
        for _ in 0..<2 {
            while scanning { try? await Task.sleep(for: .milliseconds(50)) }
            lastModelProbe = .distantPast
            await scan(full: true)
            try? await Task.sleep(for: .seconds(2))
        }
        for session in sessions {
            print("isla-agent \(session.tool.name) | \(session.model ?? "-") | \(session.contextSummary ?? "-") | pid \(session.pid) | \(session.state) | \(session.displayFolder ?? "-") | \(session.title ?? "-") | host \(session.hostName ?? "-") | cpu \(String(format: "%.1f", session.cpu)) | \(session.step?.text ?? "-")")
        }
        for app in apps { print("isla-agent-app \(app.name) (\(app.bundleID))") }
        // Parses given session files, to check the mapping without a session in that state.
        for path in (ProcessInfo.processInfo.environment["ISLA_SESSION_SAMPLES"] ?? "").split(separator: ":") {
            guard let session = AgentSessionFiles.parse(URL(fileURLWithPath: String(path))) else { continue }
            print("isla-session \((String(path) as NSString).lastPathComponent) | status \(session.status ?? "-") | needs user \(session.needsUser) | \(session.waitingStep?.text ?? "-")")
        }
        // Parses a given Codex session log, to check the reader without a running Codex.
        for path in (ProcessInfo.processInfo.environment["ISLA_CODEX_SAMPLES"] ?? "").split(separator: ":") {
            let info = CodexTranscript.info(URL(fileURLWithPath: String(path)))
            print("isla-codex \((String(path) as NSString).lastPathComponent.prefix(36)) | busy \(info.busy.map(String.init) ?? "-") | needs user \(info.needsUser) | ctx \(info.contextTokens ?? 0)/\(info.contextWindow ?? 0) | \(info.model.map(AgentModelName.display) ?? "-") | \(info.step?.text ?? "-") | limit \(info.limitUsed.map { "\($0)%" } ?? "-")/\(info.limitWindow ?? 0)m | \(info.folder ?? "-")")
        }
        for server in servers { print("isla-agent-server \(server.name) \(server.version ?? "")") }
        for model in models { print("isla-agent-model \(model.name) \(model.detail ?? "")") }
    }
    #endif
}

// MARK: - Scanner

/// The part of a scan that runs off the main thread.
enum AgentScanner {
    struct RunningApp {
        let pid: pid_t
        let bundleID: String
        let name: String
        /// Has a Dock icon and windows (not a background service).
        let isRegular: Bool
    }

    struct Request {
        let customCommands: [String]
        let wantsSteps: Bool
        let apps: [RunningApp]
        let previousCPU: [pid_t: UInt64]
        let previousSample: Date?
        /// Sessions whose model is already known, so idle ones are not read again.
        let knownModels: Set<pid_t>
    }

    struct RawAgent {
        let pid: pid_t
        let toolID: String
        let folder: String?
        let started: Date
        let cpuPercent: Double
        let memory: UInt64
        let ancestors: [pid_t]
        var session: AgentSessionFile?
        var step: AgentStep?
        var model: String?
        var limitUsed: Double?
        var limitWindow: Int?
        var contextTokens: Int?
        var contextWindow: Int?
    }

    struct Result {
        let date: Date
        let agents: [RawAgent]
        let cpuBook: [pid_t: UInt64]
        let localServerProcesses: Set<String>
    }

    private static let argumentsLock = NSLock()
    nonisolated(unsafe) private static var argumentsCache: [String: [String]] = [:]

    /// A process's arguments never change, so each one is read once.
    private static func cachedArguments(of record: ProcessRecord) -> [String] {
        let key = "\(record.pid)-\(record.started.timeIntervalSince1970)"
        argumentsLock.lock()
        if let cached = argumentsCache[key] {
            argumentsLock.unlock()
            return cached
        }
        argumentsLock.unlock()
        let arguments = ProcessProbe.arguments(of: record.pid)
        argumentsLock.lock()
        if argumentsCache.count > 600 { argumentsCache.removeAll() }
        argumentsCache[key] = arguments
        argumentsLock.unlock()
        return arguments
    }

    static func scan(_ request: Request) -> Result {
        let now = Date()
        let records = ProcessProbe.userProcesses()
        var byPID: [pid_t: ProcessRecord] = [:]
        var children: [pid_t: [pid_t]] = [:]
        for record in records {
            byPID[record.pid] = record
            children[record.ppid, default: []].append(record.pid)
        }

        // Which tool, if any, each process is.
        var exact: [String: String] = [:]
        for tool in AgentCatalog.cli { for name in tool.executables { exact[name] = tool.id } }
        var hints: [(String, String)] = AgentCatalog.cli.flatMap { tool in tool.scriptHints.map { ($0, tool.id) } }
        for command in request.customCommands {
            let tool = AgentCatalog.custom(command)
            exact[command] = tool.id
            hints.append(("/\(command)", tool.id))
        }

        var matches: [pid_t: String] = [:]
        var localServers: Set<String> = []
        for record in records {
            if let toolID = exact[record.name] {
                // Desktop apps keep helpers inside their bundle; those are never sessions.
                if let path = ProcessProbe.executablePath(of: record.pid), path.contains(".app/Contents/Frameworks/") { continue }
                matches[record.pid] = toolID
                continue
            }
            switch record.name {
            case "ollama", "Ollama":
                localServers.insert(AgentCatalog.ollama.id)
            case "llama-server", "llama-cli":
                localServers.insert(AgentCatalog.llamaCpp.id)
            case "llmster", "lms":
                localServers.insert(AgentCatalog.lmStudio.id)
            default:
                break
            }
            if AgentCatalog.interpreters.contains(record.name) || record.name.hasPrefix("python3.") {
                let argv = cachedArguments(of: record)
                if argv.first?.contains("/.lmstudio/") == true { localServers.insert(AgentCatalog.lmStudio.id); continue }
                let arguments = argv.dropFirst().prefix(4).joined(separator: " ")
                if arguments.contains("mlx_lm") { localServers.insert(AgentCatalog.mlx.id); continue }
                if let hit = hints.first(where: { arguments.contains($0.0) }) {
                    matches[record.pid] = hit.1
                }
            }
        }
        for app in request.apps where AgentCatalog.isLMStudio(bundleIdentifier: app.bundleID) {
            localServers.insert(AgentCatalog.lmStudio.id)
        }
        for app in request.apps where AgentCatalog.isOllama(bundleIdentifier: app.bundleID) {
            localServers.insert(AgentCatalog.ollama.id)
        }

        func ancestors(of pid: pid_t) -> [pid_t] {
            var chain: [pid_t] = []
            var current = byPID[pid]?.ppid ?? 0
            while current > 1, chain.count < 40 {
                chain.append(current)
                current = byPID[current]?.ppid ?? 0
            }
            return chain
        }

        func subtree(of pid: pid_t) -> [pid_t] {
            var result: [pid_t] = [pid]
            var index = 0
            while index < result.count, result.count < 400 {
                result += children[result[index]] ?? []
                index += 1
            }
            return result
        }

        var book: [pid_t: UInt64] = [:]
        let elapsed = request.previousSample.map { now.timeIntervalSince($0) } ?? 0

        func measure(_ pid: pid_t) -> (percent: Double, memory: UInt64) {
            var delta: UInt64 = 0
            var memory: UInt64 = 0
            for member in subtree(of: pid) {
                guard let usage = ProcessProbe.usage(of: member) else { continue }
                book[member] = usage.cpu
                memory += usage.memory
                if let before = request.previousCPU[member], usage.cpu >= before {
                    delta += usage.cpu - before
                } else if let started = byPID[member]?.started, let previous = request.previousSample, started > previous {
                    delta += usage.cpu
                }
            }
            guard elapsed > 0.2, request.previousSample != nil else { return (0, memory) }
            return (Double(delta) / (elapsed * 1_000_000_000) * 100, memory)
        }

        let sessionFiles = matches.values.contains(AgentCatalog.claudeCode.id) ? AgentSessionFiles.read() : [:]
        var agents: [RawAgent] = []

        for (pid, toolID) in matches {
            let chain = ancestors(of: pid)
            // A wrapper (npx, a shell script) and the agent it starts are one session: keep the outer one.
            if chain.contains(where: { matches[$0] == toolID }) { continue }
            guard let record = byPID[pid] else { continue }
            let usage = measure(pid)
            var session = toolID == AgentCatalog.claudeCode.id ? sessionFiles[pid] : nil
            if session == nil, toolID == AgentCatalog.claudeCode.id {
                // Some launchers start the session in a child process.
                session = subtree(of: pid).dropFirst().lazy.compactMap { sessionFiles[$0] }.first
            }
            var transcript: TranscriptInfo?
            if toolID == AgentCatalog.codex.id {
                // Codex has no status file: its session log says whether a turn is running.
                let folder = ProcessProbe.workingDirectory(of: pid)
                if let url = CodexTranscript.rollout(for: pid, folder: folder, started: record.started) {
                    let info = CodexTranscript.info(url)
                    transcript = info
                    session = AgentSessionFile(pid: pid, sessionID: nil, folder: info.folder ?? folder, name: nil,
                                               status: info.needsUser ? "waiting" : info.busy.map { $0 ? "busy" : "idle" },
                                               started: nil, statusChanged: info.changed,
                                               waitingFor: info.needsUser ? "permission prompt" : nil)
                }
            } else if let id = session?.sessionID {
                // Sessions in the middle of a turn have a step worth reading; the others only
                // once, to learn their model.
                let busy = session?.status == nil || session?.isBusy == true || session?.needsUser == true
                if (request.wantsSteps && busy) || !request.knownModels.contains(pid) {
                    transcript = AgentTranscript.info(sessionID: id, folder: session?.folder)
                }
            }
            var agent = RawAgent(pid: pid, toolID: toolID,
                                 folder: session?.folder ?? ProcessProbe.workingDirectory(of: pid),
                                 started: record.started, cpuPercent: usage.percent, memory: usage.memory,
                                 ancestors: chain, session: session)
            if request.wantsSteps, session?.status == nil || session?.isBusy == true || session?.needsUser == true {
                agent.step = transcript?.step
            }
            agent.model = transcript?.model
            agent.limitUsed = transcript?.limitUsed
            agent.limitWindow = transcript?.limitWindow
            agent.contextTokens = transcript?.contextTokens
            agent.contextWindow = transcript?.contextWindow
            agents.append(agent)
        }

        // Editors built around an agent: one row per app, named after its open project.
        for app in request.apps where app.isRegular {
            guard let tool = AgentCatalog.editor(forBundle: app.bundleID) else { continue }
            let usage = measure(app.pid)
            let folders = tool.appSupportFolder.map(EditorWindows.folders(appSupportFolder:)) ?? []
            agents.append(RawAgent(pid: app.pid, toolID: tool.id, folder: folders.first,
                                   started: byPID[app.pid]?.started ?? now,
                                   cpuPercent: usage.percent, memory: usage.memory, ancestors: [], session: nil))
        }

        return Result(date: now, agents: agents, cpuBook: book, localServerProcesses: localServers)
    }
}

extension String {
    /// Names typed in capitals ("ISLA - APP NOTCH MAC", a folder called "NOTCHY CLONE") read
    /// like shouting next to the others: they show as "Isla - App Notch Mac". Names with any
    /// lowercase letter stay exactly as they are.
    var readableName: String {
        let letters = unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 4, !contains(where: \.isLowercase) else { return self }
        return lowercased().capitalized(with: .current)
    }
}
