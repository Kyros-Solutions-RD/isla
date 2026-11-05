//
//  AgentSources.swift
//  Isla
//
//  Files and local endpoints the agents themselves keep up to date: the
//  CLI's per-session JSON and transcript, the window state of agent editors,
//  and the Ollama and LM Studio servers on this Mac.
//

import Foundation

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

    var isBusy: Bool { status.map(Self.isBusy) ?? false }

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
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pidNumber = object["pid"] as? NSNumber else { continue }
            let pid = pid_t(truncating: pidNumber)
            result[pid] = AgentSessionFile(
                pid: pid,
                sessionID: object["sessionId"] as? String,
                folder: object["cwd"] as? String,
                name: (object["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
                status: object["status"] as? String,
                started: date(object["startedAt"]),
                statusChanged: date(object["statusUpdatedAt"]) ?? date(object["updatedAt"]))
        }
        return result
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

    /// The latest thing the session did, from the tail of its transcript.
    static func latestStep(sessionID: String, folder: String?) -> AgentStep? {
        guard let url = location(sessionID: sessionID, folder: folder),
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }

        for window in [UInt64(96 * 1024), UInt64(768 * 1024)] {
            let start = size > window ? size - window : 0
            try? handle.seek(toOffset: start)
            guard let data = try? handle.readToEnd() else { return nil }
            var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
            if start > 0, !lines.isEmpty { lines.removeFirst() } // partial line
            for line in lines.reversed().prefix(60) {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                if let step = step(from: object) { return step }
            }
            if start == 0 { break }
        }
        return nil
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
        let date = (object["timestamp"] as? String).flatMap(parseDate)
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

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
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
