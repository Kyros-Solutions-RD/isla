//
//  DownloadsWatcher.swift
//  Isla
//
//  Shows browser downloads as a live activity. Safari reports exact progress;
//  other browsers show a lively indeterminate ring until they finish.
//

import AppKit

struct ActiveDownload: Equatable {
    var name: String
    var progress: Double?
}

@Observable
@MainActor
final class DownloadsWatcher {
    static let shared = DownloadsWatcher()

    private(set) var activeDownload: ActiveDownload?

    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var tracked: [String: URL] = [:] // partial name → expected final URL
    @ObservationIgnored private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

    private static let partialSuffixes = [".download", ".crdownload", ".part", ".opdownload", ".partial"]

    private init() {}

    func start() {
        guard source == nil else { return }
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { DownloadsWatcher.shared.scan() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        scan()
    }

    func stop() {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
        activeDownload = nil
    }

    private func scan() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        let partials = names.filter { name in Self.partialSuffixes.contains { name.hasSuffix($0) } && !name.hasPrefix(".") }

        // Finished: a tracked partial disappeared and its final file is present.
        for (partial, finalURL) in tracked where !partials.contains(partial) {
            tracked[partial] = nil
            if FileManager.default.fileExists(atPath: finalURL.path), Preferences.shared.activityDownloads {
                LiveActivityCenter.shared.post(.downloadFinished(name: finalURL.lastPathComponent, url: finalURL), duration: 4)
            }
        }

        for partial in partials where tracked[partial] == nil {
            let suffix = Self.partialSuffixes.first { partial.hasSuffix($0) } ?? ""
            let finalName = String(partial.dropLast(suffix.count))
            tracked[partial] = folder.appendingPathComponent(finalName)
        }

        if let first = partials.sorted().first {
            let url = folder.appendingPathComponent(first)
            let suffix = Self.partialSuffixes.first { first.hasSuffix($0) } ?? ""
            activeDownload = ActiveDownload(name: String(first.dropLast(suffix.count)), progress: Self.safariProgress(url))
            if pollTimer == nil {
                pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    MainActor.assumeIsolated { DownloadsWatcher.shared.scan() }
                }
            }
        } else {
            activeDownload = nil
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    private static func safariProgress(_ bundle: URL) -> Double? {
        let plist = bundle.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let received = info["DownloadEntryProgressBytesSoFar"] as? Double,
              let total = info["DownloadEntryProgressTotalToLoad"] as? Double, total > 0 else { return nil }
        return min(1, received / total)
    }
}

/// Watches Caps Lock without any special permission.
@MainActor
final class CapsLockMonitor {
    static let shared = CapsLockMonitor()

    private var timer: Timer?
    private var lastState = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)

    private init() {}

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { CapsLockMonitor.shared.check() }
        }
        timer?.tolerance = 0.05
    }

    private func check() {
        let state = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        guard state != lastState else { return }
        lastState = state
        guard Preferences.shared.activityCapsLock else { return }
        LiveActivityCenter.shared.post(.capsLock(state), duration: 1.6)
    }
}
