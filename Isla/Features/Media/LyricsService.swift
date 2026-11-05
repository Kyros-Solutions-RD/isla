//
//  LyricsService.swift
//  Isla
//
//  Time-synced lyrics from LRCLIB, the free and open lyrics database.
//

import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: TimeInterval
    let text: String
}

@Observable
@MainActor
final class LyricsService {
    static let shared = LyricsService()

    private(set) var lines: [LyricLine] = []
    private(set) var plainLyrics: String?
    private(set) var isLoading = false
    private(set) var trackKey: String?

    @ObservationIgnored private var cache: [String: [LyricLine]] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?

    private init() {}

    var hasSyncedLyrics: Bool { !lines.isEmpty }

    func clear() {
        task?.cancel()
        lines = []
        plainLyrics = nil
        trackKey = nil
    }

    func line(at time: TimeInterval) -> LyricLine? {
        guard !lines.isEmpty else { return nil }
        var low = 0, high = lines.count - 1, match: LyricLine?
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time + 0.25 {
                match = lines[mid]
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return match
    }

    func load(for info: NowPlayingInfo) {
        guard Preferences.shared.lyricsEnabled else { clear(); return }
        let key = info.trackKey
        guard key != trackKey else { return }
        trackKey = key
        task?.cancel()
        if let cached = cache[key] {
            lines = cached
            return
        }
        lines = []
        plainLyrics = nil
        isLoading = true

        task = Task { [weak self] in
            let result = await Self.fetch(title: info.title, artist: info.artist, album: info.album, duration: info.duration)
            guard let self, !Task.isCancelled, self.trackKey == key else { return }
            self.isLoading = false
            self.lines = result.lines
            self.plainLyrics = result.plain
            self.cache[key] = result.lines
        }
    }

    private static func fetch(title: String, artist: String, album: String, duration: TimeInterval) async -> (lines: [LyricLine], plain: String?) {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var items = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        components.queryItems = items
        guard let url = components.url else { return ([], nil) }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Isla/1.0 (https://github.com/Kyros-Solutions-RD/isla)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], nil)
        }
        let synced = json["syncedLyrics"] as? String
        let plain = json["plainLyrics"] as? String
        return (synced.map(parse) ?? [], plain)
    }

    /// Parses LRC: "[01:23.45] line"
    static func parse(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let pattern = /\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]/
        for rawLine in lrc.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let matches = line.matches(of: pattern)
            guard let last = matches.last else { continue }
            let text = String(line[last.range.upperBound...]).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(match.output.1) ?? 0
                let seconds = Double(match.output.2) ?? 0
                var fraction = 0.0
                if let f = match.output.3 {
                    fraction = (Double(f) ?? 0) / pow(10, Double(f.count))
                }
                result.append(LyricLine(id: result.count, time: minutes * 60 + seconds + fraction, text: text))
            }
        }
        return result.sorted { $0.time < $1.time }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text) }
    }
}
