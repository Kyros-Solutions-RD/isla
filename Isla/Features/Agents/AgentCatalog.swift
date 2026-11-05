//
//  AgentCatalog.swift
//  Isla
//
//  The AI tools Isla recognizes: command-line coding agents, editors built
//  around an agent, chat apps and local model servers. Brand names are
//  shown as they are and never translated.
//

import AppKit
import SwiftUI

/// How a tool shows up on the Mac.
enum AgentToolKind {
    /// A command-line agent: one process per session, with its own folder.
    case cli
    /// An editor whose agent works inside the app's windows.
    case editor
}

struct AgentTool: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let colors: [Color]
    var kind: AgentToolKind = .cli
    /// Exact executable names (case-sensitive).
    var executables: Set<String> = []
    /// Fragments of the script path for agents started by node, bun or python.
    var scriptHints: [String] = []
    /// Bundle identifier fragments for editors.
    var bundleHints: [String] = []
    /// Folder in ~/Library/Application Support with the editor's window state.
    var appSupportFolder: String? = nil

    static func == (lhs: AgentTool, rhs: AgentTool) -> Bool { lhs.id == rhs.id }

    var tint: Color { colors.first ?? .white }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func rgb(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
}

enum AgentCatalog {
    static let claudeCode = AgentTool(
        id: "claude-code", name: "Claude Code", symbol: "sparkle", colors: [rgb(0xE5896A), rgb(0xC15F3C)],
        executables: ["claude"], scriptHints: ["@anthropic-ai/claude-code", "claude-code/cli"])

    static let codex = AgentTool(
        id: "codex", name: "Codex", symbol: "chevron.left.forwardslash.chevron.right", colors: [rgb(0x8E8CFF), rgb(0x5552E0)],
        executables: ["codex", "codex-aarch64-apple-darwin", "codex-x86_64-apple-darwin"], scriptHints: ["@openai/codex"])

    static let gemini = AgentTool(
        id: "gemini", name: "Gemini CLI", symbol: "sparkles", colors: [rgb(0x5B9BFF), rgb(0x9C6BE3)],
        executables: ["gemini"], scriptHints: ["@google/gemini-cli", "gemini-cli/"])

    static let cli: [AgentTool] = [
        claudeCode,
        codex,
        gemini,
        AgentTool(id: "cursor-agent", name: "Cursor Agent", symbol: "cursorarrow.rays", colors: [rgb(0x9AA4B5), rgb(0x5C6576)],
                  executables: ["cursor-agent"]),
        AgentTool(id: "copilot", name: "Copilot CLI", symbol: "airplane", colors: [rgb(0x7FB2FF), rgb(0x3E6FD8)],
                  executables: ["copilot"], scriptHints: ["@github/copilot"]),
        AgentTool(id: "qwen", name: "Qwen Code", symbol: "q.circle.fill", colors: [rgb(0xA98BFF), rgb(0x6A4BD6)],
                  executables: ["qwen"], scriptHints: ["@qwen-code/qwen-code"]),
        AgentTool(id: "opencode", name: "OpenCode", symbol: "curlybraces", colors: [rgb(0xB8BEC8), rgb(0x6E7480)],
                  executables: ["opencode"], scriptHints: ["opencode-ai"]),
        AgentTool(id: "aider", name: "Aider", symbol: "wand.and.stars", colors: [rgb(0x5FD38A), rgb(0x2E9E5B)],
                  executables: ["aider"], scriptHints: ["/bin/aider", "aider-chat"]),
        AgentTool(id: "goose", name: "Goose", symbol: "bird.fill", colors: [rgb(0xF5C65B), rgb(0xD69524)],
                  executables: ["goose"]),
        AgentTool(id: "amp", name: "Amp", symbol: "bolt.fill", colors: [rgb(0xFF8A65), rgb(0xE0472F)],
                  executables: ["amp"], scriptHints: ["@sourcegraph/amp"]),
        AgentTool(id: "crush", name: "Crush", symbol: "heart.fill", colors: [rgb(0xFF8FC8), rgb(0xD94E96)],
                  executables: ["crush"]),
        AgentTool(id: "kiro-cli", name: "Kiro CLI", symbol: "k.circle.fill", colors: [rgb(0xB18CFF), rgb(0x7A4FE0)],
                  executables: ["kiro-cli"]),
    ]

    static let editors: [AgentTool] = [
        AgentTool(id: "antigravity", name: "Antigravity", symbol: "atom", colors: [rgb(0x63B3FF), rgb(0x2D6FE8)],
                  kind: .editor, bundleHints: ["antigravity"], appSupportFolder: "Antigravity"),
        AgentTool(id: "cursor", name: "Cursor", symbol: "cursorarrow.rays", colors: [rgb(0x9AA4B5), rgb(0x5C6576)],
                  kind: .editor, bundleHints: ["com.todesktop.230313mt0ot"], appSupportFolder: "Cursor"),
        AgentTool(id: "windsurf", name: "Windsurf", symbol: "wind", colors: [rgb(0x5CE0C6), rgb(0x1E9E8A)],
                  kind: .editor, bundleHints: ["com.exafunction.windsurf"], appSupportFolder: "Windsurf"),
        AgentTool(id: "kiro", name: "Kiro", symbol: "k.circle.fill", colors: [rgb(0xB18CFF), rgb(0x7A4FE0)],
                  kind: .editor, bundleHints: ["dev.kiro"], appSupportFolder: "Kiro"),
        AgentTool(id: "trae", name: "Trae", symbol: "triangle.fill", colors: [rgb(0x7CF29A), rgb(0x2DB35A)],
                  kind: .editor, bundleHints: ["com.trae."], appSupportFolder: "Trae"),
    ]

    /// Tools shown on the empty state, as examples of what Isla finds.
    static let showcase: [AgentTool] = [claudeCode, codex, gemini, editors[0], ollama, lmStudio]

    /// A tool the user added by its command name in Settings.
    static func custom(_ command: String) -> AgentTool {
        AgentTool(id: "custom-\(command)", name: command, symbol: "sparkles", colors: [rgb(0xC9CDD6), rgb(0x7D828C)],
                  executables: [command], scriptHints: ["/\(command)"])
    }

    static func tool(id: String) -> AgentTool? {
        if id.hasPrefix("custom-") { return custom(String(id.dropFirst("custom-".count))) }
        return (cli + editors + [ollama, lmStudio]).first { $0.id == id }
    }

    /// Interpreters that run script-based agents; their arguments say which agent it is.
    static let interpreters: Set<String> = ["node", "bun", "deno", "python", "python3", "Python", "uv", "uvx", "pipx"]

    // MARK: Local models

    static let ollama = AgentTool(id: "ollama", name: "Ollama", symbol: "shippingbox.fill", colors: [rgb(0xE8E8E8), rgb(0x9A9A9A)])
    static let lmStudio = AgentTool(id: "lmstudio", name: "LM Studio", symbol: "cpu.fill", colors: [rgb(0x9C8CFF), rgb(0x5B47E0)])
    static let llamaCpp = AgentTool(id: "llamacpp", name: "llama.cpp", symbol: "server.rack", colors: [rgb(0xFFB86B), rgb(0xD9822B)])
    static let mlx = AgentTool(id: "mlx", name: "MLX", symbol: "square.stack.3d.up.fill", colors: [rgb(0xFF9F9F), rgb(0xD95C5C)])

    // MARK: Chat and assistant apps

    /// Bundle identifier prefixes of AI apps worth listing while they are open.
    static let appBundlePrefixes: [String] = [
        "com.anthropic.",          // Claude
        "com.openai.",             // ChatGPT, Codex
        "com.google.antigravity",
        "com.todesktop.230313mt0ot", // Cursor
        "com.exafunction.windsurf",
        "dev.kiro",
        "com.trae.",
        "ai.elementlabs.",         // LM Studio
        "com.electron.ollama", "com.ollama.",
        "com.microsoft.m365copilot", "com.microsoft.copilot",
        "ai.perplexity.",
        "com.stablyai.",
        "jan.ai.", "ai.jan.",
        "io.gpt4all.", "app.msty.",
        "com.mistral.", "ai.x.grok", "com.x.grok",
    ]

    static func isAIApp(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        let lower = bundleIdentifier.lowercased()
        return appBundlePrefixes.contains { lower.hasPrefix($0.lowercased()) }
    }

    static func editor(forBundle bundleIdentifier: String?) -> AgentTool? {
        guard let lower = bundleIdentifier?.lowercased() else { return nil }
        return editors.first { tool in tool.bundleHints.contains { lower.contains($0.lowercased()) } }
    }

    static func isLMStudio(bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.lowercased().hasPrefix("ai.elementlabs.") ?? false
    }

    static func isOllama(bundleIdentifier: String?) -> Bool {
        guard let lower = bundleIdentifier?.lowercased() else { return false }
        return lower.hasPrefix("com.electron.ollama") || lower.hasPrefix("com.ollama.")
    }

    // MARK: Session files

    /// Folder where the CLI keeps one JSON file per running session.
    static var sessionsFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/sessions", isDirectory: true)
    }

    /// Folder with one transcript per session, grouped by project.
    static var transcriptsFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
    }
}
