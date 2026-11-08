//
//  LauncherEngine.swift
//  Isla
//
//  What the launcher finds for what you type: apps, files (through Spotlight's index, with
//  no file opened or read), Isla's own tabs and actions, the clipboard, calculations,
//  conversions and a web search. Results you pick rise to the top next time.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LauncherResult: Identifiable {
    enum Icon {
        case app(URL)
        case symbol(String, Color)
        case fileType(String)
    }

    enum Kind {
        case answer, app, isla, file, clipboard, web, ai

        var label: LocalizedStringKey {
            switch self {
            case .answer: "Result"
            case .app: "App"
            case .isla: "Isla"
            case .file: "File"
            case .clipboard: "Clipboard"
            case .web: "Web"
            case .ai: "Local AI"
            }
        }
    }

    let id: String
    var kind: Kind
    var title: String
    var subtitle: String
    var icon: Icon
    var score: Int
    /// What Return does, shown on the selected row.
    var actionName: LocalizedStringKey = "Open"
    var run: @MainActor () -> Void
    /// ⌘Return: show the file in Finder.
    var reveal: (@MainActor () -> Void)?
}

@Observable
@MainActor
final class LauncherEngine {
    static let shared = LauncherEngine()

    var query = "" { didSet { if query != oldValue { refresh() } } }
    private(set) var results: [LauncherResult] = []
    var selectedID: String?
    /// The big answer card: a calculation or a conversion.
    private(set) var answer: LauncherResult?
    /// Apps you open most, for the empty launcher.
    private(set) var favorites: [AppEntry] = []
    /// Brief confirmation under the field ("Copied").
    private(set) var flash: LocalizedStringKey?

    struct AppEntry: Identifiable, Hashable {
        var id: String { url.path }
        let name: String
        let url: URL
        /// Name folded for matching (no case, no accents).
        let key: String
    }

    @ObservationIgnored private var apps: [AppEntry] = []
    @ObservationIgnored private var indexing = false
    @ObservationIgnored private var fileResults: [LauncherResult] = []
    @ObservationIgnored private var currencyAnswer: LauncherResult?
    @ObservationIgnored private var metadata: NSMetadataQuery?
    @ObservationIgnored private var metadataObserver: NSObjectProtocol?
    @ObservationIgnored private var fileTask: Task<Void, Never>?
    @ObservationIgnored private var currencyTask: Task<Void, Never>?
    @ObservationIgnored private var flashTask: Task<Void, Never>?
    @ObservationIgnored private var usage: [String: Int]

    private static let usageKey = "launcherUsage"

    private init() {
        usage = (UserDefaults.standard.dictionary(forKey: Self.usageKey) as? [String: Int]) ?? [:]
    }

    // MARK: Lifecycle

    /// Indexes the installed apps the first time the launcher opens (off the main thread).
    func prepare() {
        Task { await LocalChat.shared.refreshModels() }
        guard apps.isEmpty, !indexing else { return }
        indexing = true
        Task.detached(priority: .userInitiated) {
            let found = Self.scanApplications()
            await MainActor.run {
                self.apps = found
                self.indexing = false
                self.favorites = self.topApps()
                self.refresh(searching: !self.query.isEmpty)
            }
        }
    }

    func reset() {
        query = ""
        stopFileSearch()
        currencyTask?.cancel()
        results = []
        answer = nil
        selectedID = nil
    }

    nonisolated private static func scanApplications() -> [AppEntry] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let roots = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                     "\(home)/Applications", "/System/Library/CoreServices/Applications"]
        var seen = Set<String>()
        var entries: [AppEntry] = []
        func add(_ path: String) {
            let url = URL(fileURLWithPath: path)
            guard !seen.contains(url.resolvingSymlinksInPath().path) else { return }
            seen.insert(url.resolvingSymlinksInPath().path)
            var name = fm.displayName(atPath: path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            entries.append(AppEntry(name: name, url: url, key: fold(name)))
        }
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                let path = (root as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    add(path)
                } else if !item.hasPrefix("."), root == "/Applications" || root.hasSuffix("/Applications"),
                          let inner = try? fm.contentsOfDirectory(atPath: path) {
                    // One level of folders ("Setapp", "Adobe…").
                    for app in inner where app.hasSuffix(".app") { add((path as NSString).appendingPathComponent(app)) }
                }
            }
        }
        add("/System/Library/CoreServices/Finder.app")
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    // MARK: Matching

    /// How well `name` matches `query` (already folded): exact, prefix, word start,
    /// initials ("vsc" → Visual Studio Code), contained or in order.
    nonisolated static func score(_ name: String, _ query: String) -> Int? {
        guard !query.isEmpty else { return nil }
        if name == query { return 1000 }
        if name.hasPrefix(query) { return 860 - min(name.count, 60) }
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." || $0 == "_" })
        if words.contains(where: { $0.hasPrefix(query) }) { return 700 - min(name.count, 60) }
        let initials = String(words.compactMap(\.first))
        if query.count >= 2, initials.hasPrefix(query) { return 620 }
        if name.contains(query) { return 480 - min(name.count, 60) }
        // Letters in order ("sfri" → Safari).
        var remaining = Substring(query)
        for char in name where char == remaining.first { remaining = remaining.dropFirst() }
        return remaining.isEmpty && query.count >= 3 ? 200 - min(name.count, 60) : nil
    }

    private func bonus(_ id: String) -> Int { min((usage[id] ?? 0) * 25, 250) }

    private func topApps() -> [AppEntry] {
        let ranked = apps.filter { (usage["app:\($0.url.path)"] ?? 0) > 0 }
            .sorted { (usage["app:\($0.url.path)"] ?? 0) > (usage["app:\($1.url.path)"] ?? 0) }
        if ranked.count >= 6 { return Array(ranked.prefix(6)) }
        // Until there is a history: the apps most people open.
        let defaults = ["safari", "mail", "mensajes", "messages", "calendario", "calendar", "notas", "notes", "finder", "musica", "música", "music", "ajustes del sistema", "system settings"]
        var picks = ranked
        for key in defaults {
            if let app = apps.first(where: { $0.key == Self.fold(key) }), !picks.contains(app) { picks.append(app) }
            if picks.count >= 6 { break }
        }
        return picks
    }

    // MARK: Results

    /// Rebuilds the list. `searching` also starts the slower lookups (Spotlight, exchange
    /// rates); their own results call back in without it, so a search never restarts itself.
    private func refresh(searching: Bool = true) {
        let text = query.trimmingCharacters(in: .whitespaces)
        let folded = Self.fold(text)
        if searching {
            currencyTask?.cancel()
            currencyAnswer = nil
        }
        guard !text.isEmpty else {
            stopFileSearch()
            results = []
            answer = nil
            selectedID = nil
            favorites = topApps()
            return
        }

        var found: [LauncherResult] = []
        answer = computeAnswer(text) ?? currencyAnswer

        for app in apps {
            guard let score = Self.score(app.key, folded) else { continue }
            let id = "app:\(app.url.path)"
            found.append(LauncherResult(id: id, kind: .app, title: app.name, subtitle: Self.location(of: app.url),
                                        icon: .app(app.url), score: score + bonus(id) + 40) { [weak self] in
                self?.note(id)
                NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
                NotchManager.shared.closeAll()
            })
        }
        found += islaCommands(text, folded)
        found += clipboardMatches(folded)
        found += fileResults

        found.sort { $0.score > $1.score }
        var list = Array(found.prefix(24))
        // Always offer the web and the local models last.
        list.append(webSearch(text))
        if LocalChat.shared.canAsk { list.append(askAI(text)) }
        results = list
        if let answer { selectedID = answer.id } else if !results.contains(where: { $0.id == selectedID }) { selectedID = results.first?.id }

        guard searching else { return }
        scheduleFileSearch(text)
        scheduleCurrency(text)
    }

    private func computeAnswer(_ text: String) -> LauncherResult? {
        if let value = Calculator.evaluate(text) {
            let shown = Calculator.format(value)
            let plain = Calculator.plain(value)
            return LauncherResult(id: "answer", kind: .answer, title: shown, subtitle: text, icon: .symbol("equal", .orange),
                                  score: 2000, actionName: "Copy") { [weak self] in
                self?.copy(plain)
            }
        }
        if let request = Converter.parse(text), let conversion = Converter.convertUnits(request) {
            return conversionResult(conversion)
        }
        return nil
    }

    private func conversionResult(_ conversion: Conversion) -> LauncherResult {
        let value = Calculator.format(conversion.result, fraction: conversion.source == nil ? 3 : 2)
        let title = "\(value) \(conversion.to)"
        let subtitle = "\(Calculator.format(conversion.amount)) \(conversion.from)" + (conversion.source.map { " · \($0)" } ?? "")
        let symbol = conversion.source == nil ? "arrow.left.arrow.right" : "dollarsign.arrow.circlepath"
        return LauncherResult(id: "answer", kind: .answer, title: title, subtitle: subtitle, icon: .symbol(symbol, .green),
                              score: 2000, actionName: "Copy") { [weak self] in
            self?.copy(Calculator.plain(conversion.result))
        }
    }

    private func scheduleCurrency(_ text: String) {
        guard answer == nil, let request = Converter.parse(text), Converter.isCurrency(request) else { return }
        currencyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let conversion = await Converter.convertCurrency(request) else { return }
            guard let self, !Task.isCancelled, self.query.trimmingCharacters(in: .whitespaces) == text else { return }
            withAnimation(IslaMotion.snappy) {
                self.currencyAnswer = self.conversionResult(conversion)
                self.answer = self.currencyAnswer
                self.selectedID = "answer"
            }
        }
    }

    private static func location(of url: URL) -> String {
        let folder = url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return folder.hasPrefix(home) ? "~" + folder.dropFirst(home.count) : folder
    }

    // MARK: Isla

    private func islaCommands(_ text: String, _ folded: String) -> [LauncherResult] {
        var commands: [LauncherResult] = []
        func command(_ id: String, _ title: String, _ symbol: String, _ color: Color, keywords: [String] = [], action: @escaping @MainActor () -> Void) {
            let names = [Self.fold(title)] + keywords.map(Self.fold)
            guard let score = names.compactMap({ Self.score($0, folded) }).max() else { return }
            commands.append(LauncherResult(id: id, kind: .isla, title: title, subtitle: "Isla", icon: .symbol(symbol, color),
                                           score: score + bonus(id)) { [weak self] in
                self?.note(id)
                action()
            })
        }

        for tab in NotchTab.allCases where tab != .launcher {
            command("tab:\(tab.rawValue)", tab.titleString, tab.symbol, .accentColor, keywords: [tab.rawValue]) {
                NotchManager.shared.open(tab)
            }
        }
        let actions = QuickActions.shared
        command("action:awake", String(localized: "Keep Mac Awake"), "cup.and.saucer.fill", .orange, keywords: ["caffeinate", "despierto", "awake"]) {
            actions.toggleKeepAwake()
        }
        command("action:color", String(localized: "Pick a Color"), "eyedropper", .pink, keywords: ["color picker", "cuentagotas"]) {
            actions.pickColor(closing: NotchManager.shared.activeController)
        }
        command("action:capture", String(localized: "Capture to Shelf"), "camera.viewfinder", .teal, keywords: ["screenshot", "captura"]) {
            actions.captureScreenshot(closing: NotchManager.shared.activeController)
        }
        command("action:lock", String(localized: "Lock Screen"), "lock.fill", .gray, keywords: ["lock", "bloquear"]) {
            actions.lockScreen()
        }
        command("action:dark", String(localized: "Toggle Dark Mode"), "circle.lefthalf.filled", .indigo, keywords: ["dark mode", "modo oscuro"]) {
            actions.toggleDarkMode()
        }
        command("action:settings", String(localized: "Isla Settings"), "gearshape.fill", .gray, keywords: ["settings", "preferences", "ajustes"]) {
            NotchManager.shared.closeAll()
            SettingsWindowController.shared.show()
        }

        // "timer 25", "temporizador 10", "5 min"
        if let minutes = Self.timerMinutes(folded) {
            let label = String(localized: "Start a \(Calculator.format(minutes))-minute timer")
            commands.append(LauncherResult(id: "timer", kind: .isla, title: label, subtitle: "Isla", icon: .symbol("timer", .orange),
                                           score: 1500) {
                TimerStore.shared.startTimer(minutes: minutes)
                NotchManager.shared.open(.timers)
            })
        }
        // "nota comprar pan", "note call Ana"
        for prefix in ["nota ", "note "] where folded.hasPrefix(prefix) {
            let body = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }
            commands.append(LauncherResult(id: "note", kind: .isla, title: String(localized: "New note: \(body)"), subtitle: "Isla",
                                           icon: .symbol("note.text.badge.plus", .yellow), score: 1500) {
                _ = NotesStore.shared.create(text: body)
                NotchManager.shared.open(.notes)
            })
        }
        return commands
    }

    private static func timerMinutes(_ folded: String) -> Double? {
        let words = folded.split(separator: " ").map(String.init)
        guard let number = words.compactMap({ Double($0.replacingOccurrences(of: ",", with: ".")) }).first, number > 0, number <= 600 else { return nil }
        let rest = words.filter { Double($0.replacingOccurrences(of: ",", with: ".")) == nil }
        let timerWords: Set<String> = ["timer", "temporizador", "min", "mins", "minutos", "minutes", "m"]
        guard !rest.isEmpty, rest.allSatisfy({ timerWords.contains($0) }) else { return nil }
        return number
    }

    // MARK: Clipboard, web and the local models

    private func clipboardMatches(_ folded: String) -> [LauncherResult] {
        guard folded.count >= 2 else { return [] }
        var matches: [LauncherResult] = []
        for item in ClipboardStore.shared.items where item.kind == .text || item.kind == .link || item.kind == .color {
            let preview = item.preview
            guard Self.fold(preview).contains(folded) else { continue }
            let line = preview.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            matches.append(LauncherResult(id: "clip:\(item.id)", kind: .clipboard, title: String(line.prefix(90)),
                                          subtitle: item.date.formatted(.relative(presentation: .named)),
                                          icon: .symbol("doc.on.clipboard", .mint), score: 300, actionName: "Copy") { [weak self] in
                ClipboardStore.shared.copy(item)
                self?.showFlash("Copied")
            })
            if matches.count == 3 { break }
        }
        return matches
    }

    private func webSearch(_ text: String) -> LauncherResult {
        LauncherResult(id: "web", kind: .web, title: String(localized: "Search the web for “\(text)”"), subtitle: "Google",
                       icon: .symbol("globe", .blue), score: 0) {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: text)]
            if let url = components?.url { NSWorkspace.shared.open(url) }
            NotchManager.shared.closeAll()
        }
    }

    private func askAI(_ text: String) -> LauncherResult {
        LauncherResult(id: "ai", kind: .ai, title: String(localized: "Ask \(LocalChat.shared.modelLabel): “\(text)”"),
                       subtitle: String(localized: "On this Mac"), icon: .symbol("bubble.left.and.text.bubble.right.fill", .purple),
                       score: 0, actionName: "Ask") { [weak self] in
            LocalChat.shared.send(text)
            NotchManager.shared.open(.chat)
            self?.reset()
        }
    }

    // MARK: Files (Spotlight)

    private func scheduleFileSearch(_ text: String) {
        fileTask?.cancel()
        guard text.count >= 2, answer == nil else {
            stopFileSearch()
            return
        }
        fileTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.startFileSearch(text)
        }
    }

    private func startFileSearch(_ text: String) {
        stopFileSearch(keepResults: true)
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        // Only files you have opened (in the last two years): the ones worth finding by name.
        let since = Date.now.addingTimeInterval(-2 * 365 * 86_400) as NSDate
        query.predicate = NSPredicate(format: "(%K CONTAINS[cd] %@) AND (%K != 'com.apple.application-bundle') AND (%K > %@)",
                                      NSMetadataItemFSNameKey, text, NSMetadataItemContentTypeKey, NSMetadataItemLastUsedDateKey, since)
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        metadataObserver = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let finished = note.object as? NSMetadataQuery else { return }
                self?.collectFiles(from: finished, text: text)
            }
        }
        metadata = query
        query.start()
    }

    private func collectFiles(from query: NSMetadataQuery, text: String) {
        // A newer search replaced this one: leave it alone.
        guard query === metadata else { return }
        query.disableUpdates()
        let folded = Self.fold(text)
        var found: [LauncherResult] = []
        for index in 0..<min(query.resultCount, 400) {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !Self.noisyFolders.contains(where: { path.contains($0) }),
                  let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                  // Only names that start with what you typed, or have a word that does.
                  let base = Self.score(Self.fold(name), folded), base >= 600 else { continue }
            let type = (item.value(forAttribute: NSMetadataItemContentTypeKey) as? String) ?? "public.data"
            let url = URL(fileURLWithPath: path)
            let id = "file:\(path)"
            found.append(LauncherResult(id: id, kind: .file, title: name, subtitle: Self.location(of: url), icon: .fileType(type),
                                        score: min(base, 520) - 120 + bonus(id)) { [weak self] in
                self?.note(id)
                NSWorkspace.shared.open(url)
                NotchManager.shared.closeAll()
            } reveal: {
                NSWorkspace.shared.activateFileViewerSelecting([url])
                NotchManager.shared.closeAll()
            })
            if found.count == 6 { break }
        }
        stopFileSearch(keepResults: true)
        guard self.query.trimmingCharacters(in: .whitespaces) == text else { return }
        fileResults = found
        let selected = selectedID
        withAnimation(IslaMotion.snappy) { refresh(searching: false) }
        if let selected, results.contains(where: { $0.id == selected }) { selectedID = selected }
    }

    /// Places full of files nobody opens by name: caches, dependencies, build output.
    private static let noisyFolders = ["/Library/", "/.", "/node_modules/", "/pkg/mod/", "/DerivedData/", "/build/",
                                       "/Pods/", "/vendor/", "/.build/", "/Caches/", "/site-packages/", "/target/"]

    private func stopFileSearch(keepResults: Bool = false) {
        metadata?.stop()
        if let metadataObserver { NotificationCenter.default.removeObserver(metadataObserver) }
        metadataObserver = nil
        metadata = nil
        if !keepResults { fileResults = [] }
    }

    // MARK: Keyboard

    /// The answer card first, then the list.
    private var order: [String] { (answer.map { [$0.id] } ?? []) + results.map(\.id) }

    func move(_ delta: Int) {
        let ids = order
        guard !ids.isEmpty else { return }
        let current = selectedID.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = max(0, min(ids.count - 1, current + delta))
        withAnimation(IslaMotion.snappy) { selectedID = ids[next] }
    }

    func runSelected(reveal: Bool = false) {
        let all = (answer.map { [$0] } ?? []) + results
        guard let item = all.first(where: { $0.id == selectedID }) ?? all.first else {
            if let app = favorites.first { open(app) }
            return
        }
        Haptics.tap()
        if reveal, let show = item.reveal { show() } else { item.run() }
    }

    func open(_ app: AppEntry) {
        note("app:\(app.url.path)")
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
        NotchManager.shared.closeAll()
    }

    // MARK: Helpers

    private func note(_ id: String) {
        usage[id, default: 0] += 1
        if usage.count > 400 {
            for key in usage.sorted(by: { $0.value < $1.value }).prefix(100).map(\.key) { usage[key] = nil }
        }
        UserDefaults.standard.set(usage, forKey: Self.usageKey)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showFlash("Copied")
    }

    private func showFlash(_ text: LocalizedStringKey) {
        flashTask?.cancel()
        withAnimation(IslaMotion.snappy) { flash = text }
        Haptics.tap(.levelChange)
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(IslaMotion.snappy) { self?.flash = nil }
        }
    }
}
