//
//  NowPlayingService.swift
//  Isla
//
//  Follows whatever macOS considers "Now Playing" — Apple Music, Spotify,
//  browsers, podcasts — through the bundled media bridge, with an AppleScript
//  fallback for Music and Spotify.
//

import AppKit
import SwiftUI

struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsed: TimeInterval
    var timestamp: Date
    var rate: Double
    var isPlaying: Bool
    var bundleIdentifier: String?
    var artworkID: String?

    /// Elapsed time extrapolated to `date`.
    func elapsed(at date: Date) -> TimeInterval {
        guard isPlaying else { return min(elapsed, duration > 0 ? duration : elapsed) }
        let value = elapsed + date.timeIntervalSince(timestamp) * (rate == 0 ? 1 : rate)
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }

    var trackKey: String { "\(title)|\(artist)|\(album)" }
}

@Observable
@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private(set) var info: NowPlayingInfo?
    private(set) var artwork: NSImage?
    private(set) var accentColor: Color?
    private(set) var appIcon: NSImage?
    private(set) var appName: String?
    private(set) var usingFallback = false

    @ObservationIgnored private let bridge = MediaRemoteBridge()
    @ObservationIgnored private let fallback = ScriptedMediaSource()
    @ObservationIgnored private var lastTrackKey: String?
    @ObservationIgnored private var bridgeHasDelivered = false
    @ObservationIgnored private var fallbackTimer: Timer?

    var isPlaying: Bool { info?.isPlaying ?? false }
    var hasActiveMedia: Bool { info != nil && !(info?.title.isEmpty ?? true) }

    private init() {}

    func start() {
        bridge.onState = { [weak self] state in
            Task { @MainActor in self?.apply(bridgeState: state) }
        }
        bridge.onFailure = { [weak self] in
            Task { @MainActor in self?.enableFallback() }
        }
        bridge.start()

        // If the bridge stays silent while a scriptable player runs, poll it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, !self.bridgeHasDelivered else { return }
            self.enableFallback()
        }
    }

    func stop() {
        bridge.stop()
        fallbackTimer?.invalidate()
    }

    // MARK: Commands

    func togglePlayPause() {
        if usingFallback { fallback.send(.toggle, to: info?.bundleIdentifier) } else { bridge.send("toggle") }
        if var current = info {
            current.elapsed = current.elapsed(at: .now)
            current.timestamp = .now
            current.isPlaying.toggle()
            info = current
        }
        Haptics.tap()
    }

    func next() {
        if usingFallback { fallback.send(.next, to: info?.bundleIdentifier) } else { bridge.send("next") }
        refreshFallbackSoon()
    }

    func previous() {
        if usingFallback { fallback.send(.previous, to: info?.bundleIdentifier) } else { bridge.send("previous") }
        refreshFallbackSoon()
    }

    func seek(to seconds: TimeInterval) {
        if usingFallback { fallback.seek(to: seconds, in: info?.bundleIdentifier) } else { bridge.send("seek \(seconds)") }
        if var current = info {
            current.elapsed = seconds
            current.timestamp = .now
            info = current
        }
    }

    func openPlayer() {
        guard let bundle = info?.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: State

    private func apply(bridgeState state: MediaRemoteBridge.State) {
        if state.title?.isEmpty == false { bridgeHasDelivered = true }
        if usingFallback, state.title != nil {
            usingFallback = false
            fallbackTimer?.invalidate()
        }
        guard !usingFallback else { return }

        guard let title = state.title, !title.isEmpty else {
            update(info: nil, artworkData: nil, artworkChanged: true)
            return
        }
        let newInfo = NowPlayingInfo(title: title,
                                     artist: state.artist ?? "",
                                     album: state.album ?? "",
                                     duration: state.duration ?? 0,
                                     elapsed: state.elapsed ?? 0,
                                     timestamp: state.timestamp.map { Date(timeIntervalSince1970: $0) } ?? .now,
                                     rate: state.rate ?? (state.playing ? 1 : 0),
                                     isPlaying: state.playing,
                                     bundleIdentifier: state.bundle,
                                     artworkID: state.artworkID)
        let artworkChanged = state.artworkID != info?.artworkID || state.artworkData != nil
        update(info: newInfo, artworkData: state.artworkData, artworkChanged: artworkChanged)
    }

    private func update(info newInfo: NowPlayingInfo?, artworkData: Data?, artworkChanged: Bool) {
        let previous = info
        info = newInfo

        if newInfo == nil {
            artwork = nil
            accentColor = nil
            appIcon = nil
            appName = nil
            lastTrackKey = nil
            LyricsService.shared.clear()
            return
        }
        guard let newInfo else { return }

        if newInfo.bundleIdentifier != previous?.bundleIdentifier {
            appIcon = NSWorkspace.shared.appIcon(bundleIdentifier: newInfo.bundleIdentifier)
            appName = NSWorkspace.shared.appName(bundleIdentifier: newInfo.bundleIdentifier)
        }

        if let artworkData, let image = NSImage(data: artworkData) {
            artwork = image
            accentColor = image.vibrantColor.map { Color(nsColor: $0) }
        } else if artworkChanged, newInfo.artworkID == "none" || newInfo.artworkID == nil, newInfo.trackKey != previous?.trackKey {
            artwork = nil
            accentColor = nil
        }

        if newInfo.trackKey != lastTrackKey {
            let isFirst = lastTrackKey == nil
            lastTrackKey = newInfo.trackKey
            LyricsService.shared.load(for: newInfo)
            if !isFirst, newInfo.isPlaying, Preferences.shared.activityTrackChange {
                LiveActivityCenter.shared.post(.trackChanged, duration: 3.2)
            }
        }
    }

    #if DEBUG
    func applyDemo() {
        let art = DemoArt.album()
        usingFallback = true
        fallbackTimer?.invalidate()
        artwork = art
        accentColor = art.vibrantColor.map { Color(nsColor: $0) }
        appIcon = NSWorkspace.shared.appIcon(bundleIdentifier: "com.apple.Music")
        appName = "Music"
        info = NowPlayingInfo(title: "Brisa del Malecón", artist: "Isla Sessions", album: "Santo Domingo de Noche",
                              duration: 214, elapsed: 83, timestamp: .now, rate: 1, isPlaying: true,
                              bundleIdentifier: "com.apple.Music", artworkID: "demo")
        lastTrackKey = info?.trackKey
    }
    #endif

    // MARK: Fallback

    private func enableFallback() {
        guard !usingFallback else { return }
        usingFallback = true
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.pollFallback() }
        }
        Task { await pollFallback() }
    }

    private func refreshFallbackSoon() {
        guard usingFallback else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await pollFallback()
        }
    }

    private func pollFallback() async {
        guard usingFallback else { return }
        let result = await fallback.poll()
        guard usingFallback else { return }
        guard let result else {
            if info != nil { update(info: nil, artworkData: nil, artworkChanged: true) }
            return
        }
        let changedTrack = result.info.trackKey != info?.trackKey
        var data: Data?
        if changedTrack || artwork == nil {
            data = await fallback.artwork(for: result.info.bundleIdentifier, urlString: result.artworkURL)
        }
        update(info: result.info, artworkData: data, artworkChanged: changedTrack)
    }
}

// MARK: - Bridge process

/// Talks to the bundled bridge (`isla-media.pl` + `libIslaMediaBridge.dylib`)
/// over pipes. The bridge runs inside `/usr/bin/perl`, an Apple-signed binary.
final class MediaRemoteBridge: @unchecked Sendable {
    struct State {
        var title: String?
        var artist: String?
        var album: String?
        var duration: Double?
        var elapsed: Double?
        var rate: Double?
        var timestamp: Double?
        var playing: Bool
        var bundle: String?
        var artworkID: String?
        var artworkData: Data?
    }

    var onState: ((State) -> Void)?
    var onFailure: (() -> Void)?

    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var restarts = 0
    private var stopped = false
    private let queue = DispatchQueue(label: "isla.media.bridge.host")

    private var scriptURL: URL? { Bundle.main.url(forResource: "isla-media", withExtension: "pl") }
    private var libraryURL: URL? {
        if let bundled = Bundle.main.url(forResource: "libIslaMediaBridge", withExtension: "dylib") { return bundled }
        return Bundle.main.privateFrameworksURL?.appendingPathComponent("libIslaMediaBridge.dylib")
    }

    func start() {
        queue.async { self.launch() }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.process?.terminate()
            self.process = nil
        }
    }

    func send(_ command: String) {
        queue.async {
            guard let input = self.input else { return }
            try? input.write(contentsOf: Data((command + "\n").utf8))
        }
    }

    private func launch() {
        guard !stopped else { return }
        guard let script = scriptURL, let library = libraryURL,
              FileManager.default.fileExists(atPath: library.path) else {
            onFailure?()
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, library.path, "isla_media_stream"]
        let output = Pipe(), inputPipe = Pipe()
        process.standardOutput = output
        process.standardInput = inputPipe
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self, !data.isEmpty else { return }
            self.queue.async { self.consume(data) }
        }
        process.terminationHandler = { [weak self] finished in
            guard let self else { return }
            self.queue.async {
                output.fileHandleForReading.readabilityHandler = nil
                self.input = nil
                self.process = nil
                guard !self.stopped else { return }
                self.restarts += 1
                if self.restarts > 4 || finished.terminationStatus == 2 {
                    self.onFailure?()
                    return
                }
                self.queue.asyncAfter(deadline: .now() + Double(self.restarts) * 1.5) { self.launch() }
            }
        }

        do {
            try process.run()
            self.process = process
            self.input = inputPipe.fileHandleForWriting
        } catch {
            onFailure?()
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = object["type"] as? String else { continue }
            switch type {
            case "state":
                restarts = 0
                let artwork = (object["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
                let state = State(title: object["title"] as? String,
                                  artist: object["artist"] as? String,
                                  album: object["album"] as? String,
                                  duration: object["duration"] as? Double,
                                  elapsed: object["elapsed"] as? Double,
                                  rate: object["rate"] as? Double,
                                  timestamp: object["timestamp"] as? Double,
                                  playing: object["playing"] as? Bool ?? false,
                                  bundle: object["bundle"] as? String,
                                  artworkID: object["artworkId"] as? String,
                                  artworkData: artwork)
                onState?(state)
            case "error":
                onFailure?()
            default:
                break
            }
        }
    }
}

// MARK: - AppleScript fallback

/// Polls Apple Music and Spotify directly when the system session is unavailable.
struct ScriptedMediaSource {
    enum Command { case toggle, next, previous }

    struct Result {
        var info: NowPlayingInfo
        var artworkURL: String?
    }

    private static let players: [(bundle: String, name: String)] = [
        ("com.spotify.client", "Spotify"),
        ("com.apple.Music", "Music"),
    ]

    private func runningPlayers() -> [(bundle: String, name: String)] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return Self.players.filter { running.contains($0.bundle) }
    }

    func poll() async -> Result? {
        var paused: Result?
        for player in runningPlayers() {
            let artworkPart = player.bundle == "com.spotify.client" ? "artwork url of current track" : "\"\""
            let source = """
            tell application "\(player.name)"
                if player state is stopped then return "STOPPED"
                set t to current track
                set s to (player state as text)
                return (name of t) & "\u{1F}" & (artist of t) & "\u{1F}" & (album of t) & "\u{1F}" & ((duration of t) as text) & "\u{1F}" & ((player position) as text) & "\u{1F}" & s & "\u{1F}" & \(artworkPart)
            end tell
            """
            guard let output = await Shell.appleScript(source), output != "STOPPED" else { continue }
            let parts = output.components(separatedBy: "\u{1F}")
            guard parts.count >= 6 else { continue }
            var duration = Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0
            if player.bundle == "com.spotify.client" { duration /= 1000 } // Spotify reports milliseconds.
            let position = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
            let playing = parts[5].lowercased().contains("playing")
            let info = NowPlayingInfo(title: parts[0], artist: parts[1], album: parts[2],
                                      duration: duration, elapsed: position, timestamp: .now,
                                      rate: playing ? 1 : 0, isPlaying: playing,
                                      bundleIdentifier: player.bundle, artworkID: parts[0] + parts[2])
            let result = Result(info: info, artworkURL: parts.count > 6 ? parts[6].nonEmpty : nil)
            if playing { return result }
            paused = paused ?? result
        }
        return paused
    }

    func artwork(for bundle: String?, urlString: String?) async -> Data? {
        if let urlString, let url = URL(string: urlString) {
            return try? await URLSession.shared.data(from: url).0
        }
        guard bundle == "com.apple.Music" else { return nil }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("isla-artwork.dat").path
        let source = """
        tell application "Music"
            try
                set d to raw data of artwork 1 of current track
                set f to open for access (POSIX file "\(path)") with write permission
                set eof f to 0
                write d to f
                close access f
                return "OK"
            on error
                return ""
            end try
        end tell
        """
        guard await Shell.appleScript(source) == "OK" else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    func send(_ command: Command, to bundle: String?) {
        guard let player = Self.players.first(where: { $0.bundle == bundle }) ?? runningPlayers().first else { return }
        let verb: String
        switch command {
        case .toggle: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        }
        Task { await Shell.appleScript("tell application \"\(player.name)\" to \(verb)") }
    }

    func seek(to seconds: TimeInterval, in bundle: String?) {
        guard let player = Self.players.first(where: { $0.bundle == bundle }) ?? runningPlayers().first else { return }
        Task { await Shell.appleScript("tell application \"\(player.name)\" to set player position to \(seconds)") }
    }
}
