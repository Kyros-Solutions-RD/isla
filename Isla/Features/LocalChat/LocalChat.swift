//
//  LocalChat.swift
//  Isla
//
//  A conversation with the models in Ollama or LM Studio, streamed word by word from their
//  servers on this Mac (127.0.0.1). Nothing goes to the internet, nothing is written to disk,
//  and Isla never starts a model server on its own: it only talks to one that is running.
//

import AppKit
import Foundation
import SwiftUI

@Observable
@MainActor
final class LocalChat {
    static let shared = LocalChat()

    enum Role: Equatable { case user, assistant }

    struct Message: Identifiable, Equatable {
        let id = UUID()
        var role: Role
        var text: String
        /// The model is still writing this one.
        var streaming = false
        /// The model is reasoning (inside `<think>`), before the answer starts.
        var thinking = false
    }

    enum Server: String, Codable {
        case ollama, lmStudio

        var name: String { self == .ollama ? AgentCatalog.ollama.name : AgentCatalog.lmStudio.name }
    }

    struct ChatModel: Identifiable, Hashable {
        var id: String { "\(server.rawValue):\(name)" }
        let server: Server
        let name: String
        var loaded: Bool

        /// "qwen3-coder:30b" → "qwen3-coder 30b"; "lmstudio-community/gemma-3-12b" → "gemma-3-12b".
        var shortName: String {
            let last = name.split(separator: "/").last.map(String.init) ?? name
            return last.replacingOccurrences(of: ":latest", with: "").replacingOccurrences(of: ":", with: " ")
        }
    }

    private(set) var models: [ChatModel] = []
    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    private(set) var hasChecked = false
    private(set) var isChecking = false
    private(set) var failure: String?
    var selectedID: String? {
        didSet { UserDefaults.standard.set(selectedID, forKey: "chatModel") }
    }

    @ObservationIgnored private var responseTask: Task<Void, Never>?
    @ObservationIgnored private var lastCheck: Date?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 180
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }()

    private static let probe: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.8
        configuration.timeoutIntervalForResource = 1.6
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }()

    private init() {
        selectedID = UserDefaults.standard.string(forKey: "chatModel")
    }

    var selected: ChatModel? {
        models.first { $0.id == selectedID } ?? models.first(where: \.loaded) ?? models.first
    }

    /// Whether a question can be asked right now (as far as the last check knows).
    var canAsk: Bool { !models.isEmpty }

    var modelLabel: String { selected?.shortName ?? String(localized: "your local model") }

    // MARK: Models

    /// Looks for running servers and their models, at most every few seconds.
    func refreshModels(force: Bool = false) async {
        if !force, let lastCheck, Date.now.timeIntervalSince(lastCheck) < 4 { return }
        lastCheck = .now
        isChecking = true
        async let ollama = Self.ollamaModels()
        async let lmStudio = Self.lmStudioModels()
        let found = (await ollama ?? []) + (await lmStudio ?? [])
        models = found.sorted { ($0.loaded ? 0 : 1, $0.shortName) < ($1.loaded ? 0 : 1, $1.shortName) }
        hasChecked = true
        isChecking = false
    }

    private static func json(_ address: String) async -> Any? {
        guard let url = URL(string: address),
              let (data, response) = try? await probe.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// Every model Ollama has downloaded (it loads the one you ask on demand).
    private static func ollamaModels() async -> [ChatModel]? {
        guard let object = await json("http://127.0.0.1:11434/api/tags") as? [String: Any],
              let list = object["models"] as? [[String: Any]] else { return nil }
        let loaded = Set(((await json("http://127.0.0.1:11434/api/ps") as? [String: Any])?["models"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String })
        return list.compactMap { $0["name"] as? String }
            .filter { !$0.contains("embed") }
            .map { ChatModel(server: .ollama, name: $0, loaded: loaded.contains($0)) }
    }

    /// The chat models LM Studio offers (loaded first).
    private static func lmStudioModels() async -> [ChatModel]? {
        guard let object = await json("http://127.0.0.1:1234/api/v0/models") as? [String: Any],
              let list = object["data"] as? [[String: Any]] else { return nil }
        return list.compactMap { item -> ChatModel? in
            guard let name = item["id"] as? String, (item["type"] as? String).map({ $0 == "llm" || $0 == "vlm" }) ?? true else { return nil }
            return ChatModel(server: .lmStudio, name: name, loaded: (item["state"] as? String) == "loaded")
        }
    }

    // MARK: Talking

    func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isResponding else { return }
        failure = nil
        messages.append(Message(role: .user, text: question))
        messages.append(Message(role: .assistant, text: "", streaming: true, thinking: true))
        isResponding = true
        responseTask = Task { [weak self] in
            await self?.respond()
        }
    }

    func stop() {
        responseTask?.cancel()
        finish()
    }

    func clear() {
        stop()
        messages.removeAll()
        failure = nil
    }

    private func respond() async {
        if models.isEmpty { await refreshModels(force: true) }
        guard let model = selected else {
            failure = String(localized: "Open Ollama or LM Studio to chat with your models.")
            messages.removeLast()
            finish()
            return
        }
        let history = messages.dropLast().map { message -> [String: String] in
            ["role": message.role == .user ? "user" : "assistant", "content": message.text]
        }
        let system = ["role": "system",
                      "content": "You are a helpful assistant inside Isla, a Mac notch app. Answer in the user's language, briefly and clearly. Use Markdown only for short lists, bold and code."]
        let body: [String: Any] = ["model": model.name, "messages": [system] + history, "stream": true]
        let address = model.server == .ollama ? "http://127.0.0.1:11434/api/chat" : "http://127.0.0.1:1234/v1/chat/completions"
        guard let url = URL(string: address), let payload = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var raw = ""
        do {
            let (bytes, response) = try await Self.session.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                guard let piece = Self.piece(from: line, server: model.server) else { continue }
                if piece.done { break }
                raw += piece.text
                show(raw)
            }
        } catch {
            if !Task.isCancelled {
                failure = String(localized: "\(model.server.name) did not answer. Is the model still loading?")
                if raw.isEmpty, messages.last?.role == .assistant { messages.removeLast() }
            }
        }
        finish()
    }

    /// One streamed chunk: Ollama sends JSON lines, LM Studio sends "data: {…}" events.
    private static func piece(from line: String, server: Server) -> (text: String, done: Bool)? {
        var json = line.trimmingCharacters(in: .whitespaces)
        if server == .lmStudio {
            guard json.hasPrefix("data:") else { return nil }
            json = String(json.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if json == "[DONE]" { return ("", true) }
        }
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if server == .ollama {
            // Newer Ollama versions send any reasoning apart, in "thinking": only "content" is shown.
            let text = ((object["message"] as? [String: Any])?["content"] as? String) ?? ""
            return (text, (object["done"] as? Bool) == true && text.isEmpty)
        }
        let choice = (object["choices"] as? [[String: Any]])?.first
        let delta = choice?["delta"] as? [String: Any]
        return ((delta?["content"] as? String) ?? "", false)
    }

    /// Shows the answer so far, keeping any `<think>` reasoning out of sight.
    private func show(_ raw: String) {
        guard let index = messages.indices.last, messages[index].role == .assistant else { return }
        var text = raw
        var thinking = false
        if let open = text.range(of: "<think>") {
            if let close = text.range(of: "</think>", range: open.upperBound..<text.endIndex) {
                text.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                text = String(text[..<open.lowerBound])
                thinking = true
            }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        messages[index].text = text
        messages[index].thinking = thinking || text.isEmpty
    }

    private func finish() {
        isResponding = false
        responseTask = nil
        if let index = messages.indices.last, messages[index].role == .assistant {
            messages[index].streaming = false
            messages[index].thinking = false
            if messages[index].text.isEmpty { messages.remove(at: index) }
        }
    }

    // MARK: Servers

    /// Ollama or LM Studio, if installed as an app, to open it from the empty chat.
    static func installedServerApps() -> [(name: String, url: URL)] {
        let workspace = NSWorkspace.shared
        var apps: [(String, URL)] = []
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.electron.ollama") { apps.append((AgentCatalog.ollama.name, url)) }
        for id in ["ai.elementlabs.lmstudio", "ai.elementlabs.bionic"] {
            if let url = workspace.urlForApplication(withBundleIdentifier: id) {
                apps.append((FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), url))
                break
            }
        }
        return apps
    }
}
