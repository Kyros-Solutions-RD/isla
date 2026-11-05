//
//  UpdateChecker.swift
//  Isla
//
//  Looks for a newer release on GitHub once a day. Only the version number is
//  requested; nothing about you or your Mac is sent.
//

import AppKit

@Observable
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    static let releasesURL = URL(string: "https://github.com/Kyros-Solutions-RD/isla/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/Kyros-Solutions-RD/isla/releases/latest")!

    private(set) var latestVersion: String?
    private(set) var releaseURL: URL = UpdateChecker.releasesURL
    private(set) var isChecking = false
    private(set) var lastChecked: Date?
    private(set) var failed = false

    @ObservationIgnored private var timer: Timer?

    private init() {}

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var updateAvailable: Bool {
        guard let latestVersion else { return false }
        return Self.compare(latestVersion, isNewerThan: currentVersion)
    }

    func start() {
        guard Preferences.shared.checkForUpdates else { return }
        Task { await check(announce: true) }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.shared.check(announce: true) }
        }
    }

    func check(announce: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        failed = false
        defer { isChecking = false; lastChecked = .now }

        var request = URLRequest(url: Self.apiURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Isla/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            failed = true
            return
        }
        latestVersion = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        if let page = (json["html_url"] as? String).flatMap(URL.init(string:)) { releaseURL = page }

        let announcedKey = "announcedVersion"
        if announce, updateAvailable, UserDefaults.standard.string(forKey: announcedKey) != latestVersion {
            UserDefaults.standard.set(latestVersion, forKey: announcedKey)
            LiveActivityCenter.shared.post(.message(symbol: "arrow.down.app.fill",
                                                    title: String(localized: "Isla \(latestVersion ?? "") is available")), duration: 5)
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(releaseURL)
    }

    /// Compares dotted version strings numerically ("1.10.0" > "1.9.2").
    static func compare(_ lhs: String, isNewerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }
}
