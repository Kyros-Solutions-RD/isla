//
//  AgentSources.swift
//  Isla
//
//  Files and local endpoints the agents themselves keep up to date: the
//  CLI's per-session JSON and transcript, the window state of agent editors,
//  and the Ollama and LM Studio servers on this Mac.
//

import Foundation

/// What a transcript says about its session.
struct TranscriptInfo {
    var step: AgentStep?
    var model: String?
    /// For agents without a status file: whether a turn is in progress.
    var busy: Bool?
    var changed: Date?
    var folder: String?
    /// Share of the account's usage limit already used, and the limit's window in minutes.
    var limitUsed: Double?
    var limitWindow: Int?
    /// The turn is paused on an approval the user has to give.
    var needsUser = false
    /// Tokens in the conversation the model saw last, and the model's window when known.
    var contextTokens: Int?
    var contextWindow: Int?
}

/// What an agent is doing right now, read from its transcript.
struct AgentStep: Equatable {
    var text: String
    var symbol: String
    var date: Date?
    /// The agent stopped to ask the user something.
    var asksUser = false
}

// MARK: - Session files

/// One `<pid>.json` file the CLI writes for each running session.
struct AgentSessionFile {
    let pid: pid_t
    let sessionID: String?
    let folder: String?
    let name: String?
    let status: String?
    let started: Date?
    let statusChanged: Date?
    /// Why a waiting session stopped: "permission prompt", "input needed", "dialog open".
    var waitingFor: String? = nil

    var isBusy: Bool { status.map(Self.isBusy) ?? false }

    /// The session stopped until the user does something (approves a tool, answers, closes a dialog).
    var needsUser: Bool {
        guard let lower = status?.lowercased() else { return false }
        return lower == "waiting" || ["permission", "approv", "input", "blocked", "requires_action", "attention"].contains { lower.contains($0) }
    }

    /// What the session waits for, in the user's words.
    var waitingStep: AgentStep? {
        guard needsUser else { return nil }
        let reason = (waitingFor ?? "").lowercased()
        if reason.contains("permission") {
            return AgentStep(text: String(localized: "Waiting for your permission"), symbol: "hand.raised.fill", asksUser: true)
        }
        if reason.contains("dialog") {
            return AgentStep(text: String(localized: "Waiting for you in a dialog"), symbol: "macwindow", asksUser: true)
        }
        return AgentStep(text: String(localized: "Waiting for your answer"), symbol: "questionmark.bubble.fill", asksUser: true)
    }

    static func isBusy(_ status: String) -> Bool {
        let lower = status.lowercased()
        return ["busy", "working", "running", "thinking", "streaming", "responding"].contains { lower.contains($0) }
    }
}

enum AgentSessionFiles {
    static func read() -> [pid_t: AgentSessionFile] {
        let folder = AgentCatalog.sessionsFolder
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [:] }
        var result: [pid_t: AgentSessionFile] = [:]
        for url in files where url.pathExtension == "json" {
            if let session = parse(url) { result[session.pid] = session }
        }
        return result
    }

    static func parse(_ url: URL) -> AgentSessionFile? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pidNumber = object["pid"] as? NSNumber else { return nil }
        return AgentSessionFile(
            pid: pid_t(truncating: pidNumber),
            sessionID: object["sessionId"] as? String,
            folder: object["cwd"] as? String,
            name: (object["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            status: object["status"] as? String,
            started: date(object["startedAt"]),
            statusChanged: date(object["statusUpdatedAt"]) ?? date(object["updatedAt"]),
            waitingFor: object["waitingFor"] as? String)
    }

    private static func date(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        let raw = number.doubleValue
        return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1000 : raw)
    }
}

// MARK: - Transcripts

enum AgentTranscript {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var locations: [String: URL] = [:]

    /// The latest thing the session did and the model it uses, from the tail of its transcript.
    static func info(sessionID: String, folder: String?) -> TranscriptInfo {
        guard let url = location(sessionID: sessionID, folder: folder) else { return TranscriptInfo() }
        var info = TranscriptInfo()
        JSONLines.scanTail(of: url, windows: [96 * 1024, 768 * 1024], limit: 60) { object in
            if info.step == nil { info.step = step(from: object) }
            if object["type"] as? String == "assistant", let message = object["message"] as? [String: Any] {
                if info.model == nil, let model = message["model"] as? String, model.hasPrefix("claude") {
                    info.model = model
                }
                if info.contextTokens == nil, let usage = message["usage"] as? [String: Any] {
                    let parts = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"]
                    let total = parts.compactMap { (usage[$0] as? NSNumber)?.intValue }.reduce(0, +)
                    if total > 0 { info.contextTokens = total }
                }
            }
            return info.step != nil && info.model != nil && info.contextTokens != nil
        }
        return info
    }

    private static func location(sessionID: String, folder: String?) -> URL? {
        lock.lock()
        let cached = locations[sessionID]
        lock.unlock()
        if let cached, FileManager.default.fileExists(atPath: cached.path) { return cached }

        let root = AgentCatalog.transcriptsFolder
        let fileName = "\(sessionID).jsonl"
        var found: URL?
        if let folder {
            // Project folders are named after the path, with every other character replaced by "-".
            let slug = String(folder.map { $0.isLetter && $0.isASCII || $0.isNumber && $0.isASCII ? $0 : "-" })
            let candidate = root.appendingPathComponent(slug, isDirectory: true).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) { found = candidate }
        }
        if found == nil, let projects = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            found = projects.lazy.map { $0.appendingPathComponent(fileName) }.first { FileManager.default.fileExists(atPath: $0.path) }
        }
        if let found {
            lock.lock()
            locations[sessionID] = found
            lock.unlock()
        }
        return found
    }

    private static func step(from object: [String: Any]) -> AgentStep? {
        guard let type = object["type"] as? String, type == "assistant" || type == "user" else { return nil }
        if object["isSidechain"] as? Bool == true || object["isMeta"] as? Bool == true { return nil }
        let date = (object["timestamp"] as? String).flatMap(JSONLines.date)
        let message = object["message"] as? [String: Any]
        let content = message?["content"]

        if type == "user" {
            // A tool just returned, or the user just wrote: the agent is thinking about it.
            if content is String { return AgentStep(text: String(localized: "Reading your message"), symbol: "text.bubble", date: date) }
            if let items = content as? [[String: Any]], !items.isEmpty {
                return AgentStep(text: String(localized: "Thinking…"), symbol: "brain", date: date)
            }
            return nil
        }

        guard let items = content as? [[String: Any]], let last = items.last, let kind = last["type"] as? String else { return nil }
        switch kind {
        case "tool_use":
            let name = last["name"] as? String ?? ""
            let input = last["input"] as? [String: Any] ?? [:]
            var step = describe(tool: name, input: input)
            step.date = date
            return step
        case "thinking", "redacted_thinking":
            return AgentStep(text: String(localized: "Thinking…"), symbol: "brain", date: date)
        case "text":
            return AgentStep(text: String(localized: "Writing a reply"), symbol: "text.cursor", date: date)
        default:
            return nil
        }
    }

    private static func describe(tool: String, input: [String: Any]) -> AgentStep {
        func file(_ key: String = "file_path") -> String {
            ((input[key] as? String) ?? (input["notebook_path"] as? String) ?? (input["path"] as? String) ?? "")
                .split(separator: "/").last.map(String.init) ?? ""
        }
        func clipped(_ text: String, _ limit: Int = 90) -> String {
            let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            return line.count > limit ? String(line.prefix(limit)) + "…" : line
        }
        let description = (input["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        switch tool {
        case "Bash", "Shell", "BashOutput", "PowerShell":
            if let description { return AgentStep(text: clipped(description), symbol: "terminal") }
            let command = clipped((input["command"] as? String) ?? "", 60)
            return AgentStep(text: String(localized: "Running \(command)"), symbol: "terminal")
        case "Edit", "MultiEdit", "NotebookEdit":
            return AgentStep(text: String(localized: "Editing \(file())"), symbol: "pencil")
        case "Write":
            return AgentStep(text: String(localized: "Writing \(file())"), symbol: "square.and.pencil")
        case "Read":
            return AgentStep(text: String(localized: "Reading \(file())"), symbol: "doc.text")
        case "Grep", "Glob", "Search":
            let pattern = clipped((input["pattern"] as? String) ?? "", 40)
            return AgentStep(text: String(localized: "Searching for \(pattern)"), symbol: "magnifyingglass")
        case "WebSearch":
            let query = clipped((input["query"] as? String) ?? "", 50)
            return AgentStep(text: String(localized: "Searching the web for \(query)"), symbol: "globe")
        case "WebFetch":
            let host = (input["url"] as? String).flatMap { URL(string: $0)?.host() } ?? ""
            return AgentStep(text: String(localized: "Reading \(host)"), symbol: "globe")
        case "Task", "Agent":
            return AgentStep(text: description.map { clipped($0) } ?? String(localized: "Working with a helper agent"), symbol: "person.2.fill")
        case "TodoWrite", "TaskCreate", "TaskUpdate":
            return AgentStep(text: String(localized: "Updating its plan"), symbol: "checklist")
        case "AskUserQuestion", "ExitPlanMode":
            return AgentStep(text: String(localized: "Waiting for your answer"), symbol: "questionmark.bubble.fill", asksUser: true)
        default:
            var name = tool
            if tool.hasPrefix("mcp__"), let last = tool.components(separatedBy: "__").last { name = last }
            name = name.replacingOccurrences(of: "_", with: " ")
            return AgentStep(text: String(localized: "Using \(name)"), symbol: "hammer.fill")
        }
    }

}

// MARK: - Codex sessions

enum CodexTranscript {
    private static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    /// The session file a Codex process writes: the one it keeps open, or else the newest
    /// one for its folder that changed since it started.
    static func rollout(for pid: pid_t, folder: String?, started: Date) -> URL? {
        let open = ProcessProbe.openFiles(of: pid, containing: "/.codex/sessions/").filter { $0.hasSuffix(".jsonl") }
        if let newest = open.max(by: { modified($0) < modified($1) }) { return URL(fileURLWithPath: newest) }

        guard let folder else { return nil }
        let calendar = Calendar.current
        var days = [Date()]
        if !calendar.isDateInToday(started) { days.append(started) }
        var candidates: [(URL, Date)] = []
        for day in days {
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let dayFolder = root.appendingPathComponent(String(format: "%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
            let files = (try? FileManager.default.contentsOfDirectory(at: dayFolder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where file.pathExtension == "jsonl" {
                let date = modified(file.path)
                if date >= started.addingTimeInterval(-5) { candidates.append((file, date)) }
            }
        }
        for (file, _) in candidates.sorted(by: { $0.1 > $1.1 }).prefix(6) where sessionFolder(of: file) == folder {
            return file
        }
        return nil
    }

    /// Whether a turn is running, its latest step, the model and the usage limit.
    static func info(_ url: URL) -> TranscriptInfo {
        var info = TranscriptInfo()
        var settled = false
        JSONLines.scanTail(of: url, windows: [256 * 1024, 2 * 1024 * 1024], limit: 120) { object in
            let payload = object["payload"] as? [String: Any] ?? [:]
            let kind = payload["type"] as? String ?? ""
            let date = (object["timestamp"] as? String).flatMap(JSONLines.date)
            switch object["type"] as? String {
            case "event_msg":
                if !settled, kind.hasSuffix("approval_request") {
                    info.busy = true
                    info.needsUser = true
                    info.changed = date
                    settled = true
                    // What it asks to do: the command it wants to run or the file it wants to change.
                    if let parts = payload["command"] as? [String], let line = parts.last {
                        info.step = describe(tool: "shell", input: line)
                    } else if let changes = payload["changes"] as? [String: Any], let file = changes.keys.sorted().first {
                        info.step = AgentStep(text: String(localized: "Editing \((file as NSString).lastPathComponent)"), symbol: "pencil")
                    }
                } else if !settled, ["task_complete", "turn_aborted", "shutdown_complete"].contains(kind) {
                    info.busy = false
                    info.changed = date
                    settled = true
                } else if !settled, ["task_started", "user_message"].contains(kind) {
                    info.busy = true
                    info.changed = date
                    info.step = AgentStep(text: String(localized: "Thinking…"), symbol: "brain", date: date)
                    settled = true
                } else if kind == "token_count" {
                    if info.limitUsed == nil, let primary = (payload["rate_limits"] as? [String: Any])?["primary"] as? [String: Any] {
                        info.limitUsed = (primary["used_percent"] as? NSNumber)?.doubleValue
                        info.limitWindow = (primary["window_minutes"] as? NSNumber)?.intValue
                    }
                    if info.contextTokens == nil, let usage = payload["info"] as? [String: Any],
                       let last = usage["last_token_usage"] as? [String: Any] {
                        info.contextTokens = (last["total_tokens"] as? NSNumber)?.intValue
                            ?? [last["input_tokens"], last["output_tokens"]].compactMap { ($0 as? NSNumber)?.intValue }.reduce(0, +)
                        info.contextWindow = (usage["model_context_window"] as? NSNumber)?.intValue
                    }
                }
            case "response_item":
                if !settled, let step = step(kind: kind, payload: payload, date: date) {
                    info.busy = true
                    info.changed = date
                    info.step = step
                    settled = true
                }
            case "turn_context":
                if info.model == nil { info.model = payload["model"] as? String }
                if info.folder == nil { info.folder = payload["cwd"] as? String }
            case "session_meta":
                if info.folder == nil { info.folder = payload["cwd"] as? String }
            default:
                break
            }
            return settled && info.model != nil && info.limitUsed != nil
        }
        if info.model == nil || info.folder == nil {
            // The session's folder and model are written when each turn starts, near the top.
            JSONLines.scanHead(of: url, bytes: 512 * 1024, limit: 60) { object in
                let payload = object["payload"] as? [String: Any] ?? [:]
                let type = object["type"] as? String
                if type == "session_meta" || type == "turn_context", info.folder == nil { info.folder = payload["cwd"] as? String }
                if type == "turn_context", info.model == nil { info.model = payload["model"] as? String }
                return info.model != nil && info.folder != nil
            }
        }
        return info
    }

    private static func step(kind: String, payload: [String: Any], date: Date?) -> AgentStep? {
        switch kind {
        case "function_call", "custom_tool_call", "local_shell_call":
            let name = payload["name"] as? String ?? "shell"
            let input = (payload["arguments"] as? String) ?? (payload["input"] as? String) ?? ""
            var step = describe(tool: name, input: input)
            step.date = date
            return step
        case "reasoning":
            return AgentStep(text: String(localized: "Thinking…"), symbol: "brain", date: date)
        case "function_call_output", "custom_tool_call_output", "local_shell_call_output":
            return AgentStep(text: String(localized: "Thinking…"), symbol: "brain", date: date)
        case "message":
            let role = payload["role"] as? String
            if role == "assistant" { return AgentStep(text: String(localized: "Writing a reply"), symbol: "text.cursor", date: date) }
            if role == "user" { return AgentStep(text: String(localized: "Reading your message"), symbol: "text.bubble", date: date) }
            return nil
        default:
            return nil
        }
    }

    private static func describe(tool: String, input: String) -> AgentStep {
        func clipped(_ text: String, _ limit: Int = 60) -> String {
            let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            return line.count > limit ? String(line.prefix(limit)) + "…" : line
        }
        if input.contains("*** Begin Patch") || tool == "apply_patch" {
            let file = input.components(separatedBy: "\n")
                .first { $0.hasPrefix("*** Update File: ") || $0.hasPrefix("*** Add File: ") }?
                .components(separatedBy: ": ").last
                .map { ($0 as NSString).lastPathComponent } ?? ""
            return AgentStep(text: String(localized: "Editing \(file)"), symbol: "pencil")
        }
        switch tool {
        case "shell", "exec", "exec_command", "shell_command", "local_shell":
            return AgentStep(text: String(localized: "Running \(clipped(command(in: input)))"), symbol: "terminal")
        case "update_plan":
            return AgentStep(text: String(localized: "Updating its plan"), symbol: "checklist")
        case "web_search", "web.run", "search":
            return AgentStep(text: String(localized: "Searching the web"), symbol: "globe")
        default:
            let name = (tool.components(separatedBy: "__").last ?? tool).replacingOccurrences(of: "_", with: " ")
            return AgentStep(text: String(localized: "Using \(name)"), symbol: "hammer.fill")
        }
    }

    /// The command line inside a shell call: `{"command": [...]}`, `{"cmd": "..."}` or `cmd:"..."`.
    private static func command(in input: String) -> String {
        if let object = try? JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any] {
            if let parts = object["command"] as? [String] { return parts.last ?? "" }
            if let line = (object["cmd"] as? String) ?? (object["command"] as? String) { return line }
        }
        if let range = input.range(of: #"cmd:\s*"((?:[^"\\]|\\.)*)""#, options: .regularExpression) {
            let match = String(input[range])
            return String(match.drop(while: { $0 != "\"" }).dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
        }
        return input
    }

    private static func sessionFolder(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256 * 1024),
              let end = data.firstIndex(of: UInt8(ascii: "\n")),
              let object = try? JSONSerialization.jsonObject(with: data[..<end]) as? [String: Any] else { return nil }
        return (object["payload"] as? [String: Any])?["cwd"] as? String
    }

    private static func modified(_ path: String) -> Date {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date) ?? .distantPast
    }
}

// MARK: - JSON lines

enum JSONLines {
    /// Reads the last lines of a JSON-lines file, newest first, until `visit` returns true.
    /// Tries a small window first and a bigger one only when nothing useful was found.
    static func scanTail(of url: URL, windows: [UInt64], limit: Int, visit: ([String: Any]) -> Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return }
        var visited = 0
        for window in windows {
            let start = size > window ? size - window : 0
            try? handle.seek(toOffset: start)
            guard let data = try? handle.readToEnd() else { return }
            var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
            if start > 0, !lines.isEmpty { lines.removeFirst() } // partial line
            visited = 0
            for line in lines.reversed().prefix(limit) {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                visited += 1
                if visit(object) { return }
            }
            if start == 0 || visited >= limit { return }
        }
    }

    /// Reads the first lines of a JSON-lines file until `visit` returns true.
    static func scanHead(of url: URL, bytes: Int, limit: Int, visit: ([String: Any]) -> Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: bytes) else { return }
        var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        if data.count == bytes, !lines.isEmpty { lines.removeLast() } // partial line
        for line in lines.prefix(limit) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            if visit(object) { return }
        }
    }

    static func date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

/// "claude-opus-5-5" → "Opus 5.5", "gpt-5.5-codex" → "GPT-5.5-Codex".
enum AgentModelName {
    static func display(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("claude") {
            let parts = lower.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." || $0 == "@" }).map(String.init)
            guard let family = parts.first(where: { ["opus", "sonnet", "haiku", "fable"].contains($0) }) else { return raw }
            // Version numbers, skipping dated snapshots such as 20250929.
            let version = parts.filter { $0.allSatisfy(\.isNumber) && $0.count <= 2 }.joined(separator: ".")
            return family.capitalized + (version.isEmpty ? "" : " \(version)")
        }
        if lower.hasPrefix("gpt") {
            return lower.split(separator: "-").enumerated().map { index, part in
                index == 0 ? part.uppercased() : (part.first?.isNumber == true ? String(part) : part.capitalized)
            }.joined(separator: "-")
        }
        return raw
    }
}

// MARK: - Agent editors

enum EditorWindows {
    /// Folders open in an editor built on VS Code, read from its saved window state.
    static func folders(appSupportFolder: String) -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(appSupportFolder)/User/globalStorage/storage.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let windows = object["windowsState"] as? [String: Any] else { return [] }
        var entries: [[String: Any]] = []
        if let last = windows["lastActiveWindow"] as? [String: Any] { entries.append(last) }
        entries += (windows["openedWindows"] as? [[String: Any]]) ?? []
        var folders: [String] = []
        for entry in entries {
            let raw = (entry["folder"] as? String) ?? ((entry["workspaceIdentifier"] as? [String: Any])?["configURIPath"] as? String)
            guard let raw, let url = URL(string: raw), url.isFileURL else { continue }
            let path = url.path(percentEncoded: false)
            if !folders.contains(path) { folders.append(path) }
        }
        return folders
    }
}

// MARK: - Local models

struct LocalModel: Identifiable, Equatable {
    let id: String
    let serverID: String
    let name: String
    let detail: String?
    let bytes: Int64?
    let gpuBytes: Int64?
    let expires: Date?
    let context: Int?
}

struct LocalServer: Identifiable, Equatable {
    let id: String
    let name: String
    let version: String?
}

enum LocalModelProbe {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.8
        configuration.timeoutIntervalForResource = 1.6
        configuration.waitsForConnectivity = false
        configuration.connectionProxyDictionary = [:]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private static func json(_ address: String) async -> Any? {
        guard let url = URL(string: address) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            return nil
        }
    }

    /// Models Ollama keeps in memory right now (`/api/ps`). Nil when Ollama is not listening.
    static func ollama() async -> (server: LocalServer, models: [LocalModel])? {
        guard let object = await json("http://127.0.0.1:11434/api/ps") as? [String: Any],
              let list = object["models"] as? [[String: Any]] else { return nil }
        let version = (await json("http://127.0.0.1:11434/api/version") as? [String: Any])?["version"] as? String
        let models = list.compactMap { item -> LocalModel? in
            guard let name = (item["name"] as? String) ?? (item["model"] as? String) else { return nil }
            let details = item["details"] as? [String: Any]
            let detail = [details?["parameter_size"] as? String, details?["quantization_level"] as? String]
                .compactMap { $0?.nonEmpty }.joined(separator: " · ").nonEmpty
            return LocalModel(id: "ollama-\(name)", serverID: AgentCatalog.ollama.id, name: name, detail: detail,
                              bytes: (item["size"] as? NSNumber)?.int64Value,
                              gpuBytes: (item["size_vram"] as? NSNumber)?.int64Value,
                              expires: (item["expires_at"] as? String).flatMap(parseExpiry),
                              context: (item["context_length"] as? NSNumber)?.intValue)
        }
        return (LocalServer(id: AgentCatalog.ollama.id, name: AgentCatalog.ollama.name, version: version), models)
    }

    /// Loaded models from LM Studio's local server. Nil when the server is off.
    static func lmStudioServer() async -> [LocalModel]? {
        guard let object = await json("http://127.0.0.1:1234/api/v0/models") as? [String: Any],
              let list = object["data"] as? [[String: Any]] else { return nil }
        return list.compactMap { item -> LocalModel? in
            guard let name = item["id"] as? String, (item["state"] as? String) == "loaded" else { return nil }
            let detail = [item["arch"] as? String, item["quantization"] as? String]
                .compactMap { $0?.nonEmpty }.joined(separator: " · ").nonEmpty
            return LocalModel(id: "lmstudio-\(name)", serverID: AgentCatalog.lmStudio.id, name: name, detail: detail,
                              bytes: nil, gpuBytes: nil, expires: nil,
                              context: (item["loaded_context_length"] as? NSNumber)?.intValue ?? (item["max_context_length"] as? NSNumber)?.intValue)
        }
    }

    /// Loaded models through LM Studio's own command line tool. Only called while
    /// LM Studio is already running, so it never starts the model service itself.
    static func lmStudioCommandLine() async -> [LocalModel]? {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".lmstudio/bin/lms").path
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let result = await Shell.run(path, ["ps", "--json"])
        guard result.status == 0, let start = result.output.firstIndex(where: { $0 == "[" || $0 == "{" }),
              let object = try? JSONSerialization.jsonObject(with: Data(result.output[start...].utf8)) else { return nil }
        let list = (object as? [[String: Any]]) ?? ((object as? [String: Any])?["models"] as? [[String: Any]]) ?? []
        return list.compactMap { item -> LocalModel? in
            let name = (item["displayName"] as? String) ?? (item["identifier"] as? String) ?? (item["modelKey"] as? String) ?? (item["path"] as? String)
            guard let name else { return nil }
            let detail = [item["paramsString"] as? String, item["architecture"] as? String, item["quantization"] as? String]
                .compactMap { $0?.nonEmpty }.joined(separator: " · ").nonEmpty
            return LocalModel(id: "lmstudio-\((item["identifier"] as? String) ?? name)", serverID: AgentCatalog.lmStudio.id,
                              name: name, detail: detail,
                              bytes: (item["sizeBytes"] as? NSNumber)?.int64Value, gpuBytes: nil, expires: nil,
                              context: (item["contextLength"] as? NSNumber)?.intValue)
        }
    }

    private static func parseExpiry(_ string: String) -> Date? {
        // "2026-11-05T21:40:12.123456789-04:00": drop the fraction, which can have any length.
        let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        guard let date = ISO8601DateFormatter().date(from: trimmed) else { return nil }
        // Models pinned in memory report a date centuries away or year 1.
        let years = date.timeIntervalSinceNow / (365 * 86_400)
        return years > 5 || years < -1 ? nil : date
    }
}
