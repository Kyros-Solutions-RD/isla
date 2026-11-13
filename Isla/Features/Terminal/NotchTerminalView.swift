//
//  NotchTerminalView.swift
//  Isla
//
//  A real shell under the notch, powered by SwiftTerm. The session keeps
//  running while you switch tabs or close the Nook.
//

import AppKit
import SwiftTerm
import SwiftUI

@MainActor
final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {
    static let shared = TerminalSession()

    let view: LocalProcessTerminalView
    private(set) var isRunning = false
    private(set) var title = "zsh"
    private(set) var directory = NSHomeDirectory()

    private override init() {
        view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 180))
        super.init()
        view.processDelegate = self
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.nativeBackgroundColor = .clear
        view.nativeForegroundColor = NSColor(white: 0.95, alpha: 1)
        view.caretColor = NSColor(red: 1, green: 0.42, blue: 0.29, alpha: 1)
        view.selectedTextBackgroundColor = NSColor(red: 1, green: 0.42, blue: 0.29, alpha: 0.35)
        view.optionAsMetaKey = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    var shellName: String {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh").lastPathComponent
    }

    func startIfNeeded() {
        guard !isRunning else { return }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
        environment.append("TERM_PROGRAM=Isla")
        environment.append("LANG=\(ProcessInfo.processInfo.environment["LANG"] ?? "en_US.UTF-8")")
        view.startProcess(executable: shell, args: ["-l"], environment: environment,
                          execName: "-" + URL(fileURLWithPath: shell).lastPathComponent,
                          currentDirectory: NSHomeDirectory())
        isRunning = true
        title = shellName
    }

    func restart() {
        if isRunning { view.terminate() }
        isRunning = false
        view.resetToInitialState()
        startIfNeeded()
    }

    func clear() {
        view.send(txt: "clear\r")
    }

    func run(_ command: String) {
        startIfNeeded()
        view.send(txt: command + "\r")
    }

    func openInTerminalApp() {
        let script = "tell application \"Terminal\" to do script \"cd \(directory.replacingOccurrences(of: "\"", with: "\\\""))\""
        Task { await Shell.appleScript(script); NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")) }
    }

    // MARK: LocalProcessTerminalViewDelegate

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor in self.title = title }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory else { return }
        let path = URL(string: directory)?.path ?? directory
        Task { @MainActor in self.directory = path }
    }

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in self.isRunning = false }
    }
}

struct NotchTerminalView: View {
    @Bindable var model: NotchViewModel
    private let session = TerminalSession.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                    .fill(.black.opacity(0.42))
                TerminalHost(model: model)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(session.shellName, systemImage: "apple.terminal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                TerminalActionButton(title: "New Session", symbol: "arrow.clockwise") { session.restart() }
                TerminalActionButton(title: "Clear Screen", symbol: "eraser") { session.clear() }
                TerminalActionButton(title: "Open in Terminal", symbol: "arrow.up.forward.app") { session.openInTerminalApp() }
                Spacer(minLength: 0)
                Text("⌥ types special characters. Esc goes to the shell.")
                    .font(.system(size: 10))
                    .foregroundStyle(IslaInk.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 150)
        }
        .onAppear {
            session.startIfNeeded()
            model.holds.insert("terminal")
        }
        .onDisappear { model.holds.remove("terminal") }
    }
}

private struct TerminalActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 14)
                Text(title).font(.system(size: 11.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(hovering ? 0.13 : 0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Hosts the long-lived terminal view and gives it keyboard focus.
private struct TerminalHost: NSViewRepresentable {
    let model: NotchViewModel

    func makeNSView(context: Context) -> NSView {
        let container = TerminalContainer()
        let terminal = TerminalSession.shared.view
        terminal.removeFromSuperview()
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
        DispatchQueue.main.async {
            guard let panel = model.controller?.panel else { return }
            panel.makeKey()
            panel.makeFirstResponder(terminal)
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class TerminalContainer: NSView {
        override var needsPanelToBecomeKey: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            window?.makeFirstResponder(TerminalSession.shared.view)
            super.mouseDown(with: event)
        }
    }
}
