//
//  QuickActions.swift
//  Isla
//
//  Little utilities one click away: keep the Mac awake, pick a color from
//  anywhere on screen, capture a screenshot to the Shelf, lock the screen
//  and switch appearance.
//

import AppKit
import IOKit.pwr_mgt
import Quartz
import SwiftUI

@Observable
@MainActor
final class QuickActions {
    static let shared = QuickActions()

    private(set) var keepAwake = false
    private(set) var keepAwakeUntil: Date?
    private(set) var lastColor: String?

    @ObservationIgnored private var assertion: IOPMAssertionID = 0
    @ObservationIgnored private var keepAwakeTask: Task<Void, Never>?

    private init() {}

    // MARK: Keep awake

    func toggleKeepAwake(for duration: TimeInterval? = nil) {
        keepAwake ? stopKeepAwake() : startKeepAwake(for: duration)
    }

    func startKeepAwake(for duration: TimeInterval? = nil) {
        stopKeepAwake()
        let reason = "Isla keeps your Mac awake" as CFString
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &assertion)
        guard result == kIOReturnSuccess else { return }
        keepAwake = true
        keepAwakeUntil = duration.map { Date.now.addingTimeInterval($0) }
        Haptics.tap(.levelChange)
        LiveActivityCenter.shared.post(.message(symbol: "cup.and.saucer.fill", title: String(localized: "Keeping your Mac awake")), duration: 1.8)
        if let duration {
            keepAwakeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                self?.stopKeepAwake()
            }
        }
    }

    func stopKeepAwake() {
        keepAwakeTask?.cancel()
        if keepAwake { IOPMAssertionRelease(assertion) }
        keepAwake = false
        keepAwakeUntil = nil
    }

    // MARK: Color picker

    func pickColor(closing controller: NotchWindowController? = nil) {
        controller?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSColorSampler().show { color in
                guard let color, let rgb = color.usingColorSpace(.sRGB) else { return }
                let hex = String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
                Task { @MainActor in
                    QuickActions.shared.lastColor = hex
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hex, forType: .string)
                    LiveActivityCenter.shared.post(.message(symbol: "eyedropper.full", title: String(localized: "\(hex) copied")), duration: 2)
                }
            }
        }
    }

    // MARK: Screenshot

    func captureScreenshot(closing controller: NotchWindowController? = nil) {
        controller?.close()
        let folder = Storage.folder("Shelf")
        let name = String(localized: "Screenshot") + " " + Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted))
        let url = ShelfStore.shared.uniqueURL(in: folder, name: name.replacingOccurrences(of: ":", with: "."), ext: "png")
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            let result = await Shell.run("/usr/sbin/screencapture", ["-i", "-o", url.path])
            guard result.status == 0, FileManager.default.fileExists(atPath: url.path) else { return }
            ShelfStore.shared.add(urls: [url], generated: true)
            if let image = NSImage(contentsOf: url) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
        }
    }

    // MARK: System

    func lockScreen() {
        typealias LockFunction = @convention(c) () -> Void
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return }
        unsafeBitCast(symbol, to: LockFunction.self)()
    }

    func toggleDarkMode() {
        Task {
            await Shell.appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
        }
    }

    func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}

/// Quick Look for Shelf items.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookController()

    private var urls: [URL] = []

    func show(_ urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        Activation.bringToFront()
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }
}

// MARK: - Nook widget

struct QuickActionsCard: View {
    let model: NotchViewModel
    private let actions = QuickActions.shared

    var body: some View {
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "Quick Actions", symbol: "bolt.fill", tint: .yellow)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 6) {
                    QuickActionTile(title: "Awake", symbol: actions.keepAwake ? "cup.and.saucer.fill" : "cup.and.saucer",
                                    active: actions.keepAwake, tint: .orange) { actions.toggleKeepAwake() }
                    QuickActionTile(title: "Color", symbol: "eyedropper.halffull", tint: .pink) { actions.pickColor(closing: model.controller) }
                    QuickActionTile(title: "Capture", symbol: "camera.viewfinder", tint: .blue) { actions.captureScreenshot(closing: model.controller) }
                    QuickActionTile(title: "Lock", symbol: "lock.fill", tint: .teal) { actions.lockScreen() }
                    QuickActionTile(title: "Dark Mode", symbol: "circle.lefthalf.filled", tint: .indigo) { actions.toggleDarkMode() }
                    QuickActionTile(title: "Terminal", symbol: "apple.terminal.fill", tint: .green) { model.select(.terminal) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct QuickActionTile: View {
    let title: LocalizedStringKey
    let symbol: String
    var active = false
    var tint: Color = .white
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? Color.black : tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(active ? tint : Color.white.opacity(hovering ? 0.16 : 0.08)))
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(hovering ? 1.06 : 1)
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(IslaMotion.snappy, value: active)
        .animation(IslaMotion.snappy, value: hovering)
    }
}
