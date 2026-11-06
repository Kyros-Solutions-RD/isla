//
//  NotificationApps.swift
//  Isla
//
//  Notification Center names the app that sent a banner ("Messages", "WhatsApp", "Mail")
//  but not its bundle. This catalog matches that name to an installed app, to show its real
//  icon and open it. iPhone apps that are not on the Mac get a monogram instead.
//

import AppKit
import SwiftUI

struct NotificationAppInfo: Hashable, Sendable, Codable {
    var name: String
    var bundleID: String?
    var url: URL?
    /// The key used for the per-app setting: the bundle ID, or the name when it is unknown.
    var key: String { bundleID ?? "name:\(name)" }
}

@MainActor
final class NotificationApps {
    static let shared = NotificationApps()

    nonisolated static var remindersName: String {
        FileManager.default.displayName(atPath: "/System/Applications/Reminders.app")
            .replacingOccurrences(of: ".app", with: "")
    }

    /// Apps whose banners are people writing to you: those nudge the island when they arrive.
    static let messagingApps: Set<String> = [
        "com.apple.MobileSMS", "com.apple.iChat", "net.whatsapp.WhatsApp", "desktop.WhatsApp", "ru.keepcoder.Telegram",
        "com.tdesktop.Telegram", "org.whispersystems.signal-desktop", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
        "com.microsoft.teams2", "com.microsoft.teams", "com.facebook.archon", "com.apple.FaceTime",
        "com.apple.TelephonyUtilities", "com.skype.skype", "us.zoom.xos", "com.viber.osx", "jp.naver.line.mac",
    ]

    /// Names a messaging app may go by when it is not installed on the Mac (mirrored from the iPhone).
    private static let messagingNames: Set<String> = ["whatsapp", "telegram", "signal", "messenger", "slack", "discord",
                                                       "teams", "line", "viber", "wechat", "instagram"]

    private var byName: [String: NotificationAppInfo] = [:]
    private var indexing = false
    private var icons: [String: NSImage] = [:]
    private var tints: [String: Color] = [:]

    private init() {}

    /// Reads the installed apps once, in the background.
    func prepare() {
        guard byName.isEmpty, !indexing else { return }
        indexing = true
        Task.detached(priority: .utility) {
            let index = Self.buildIndex()
            await MainActor.run {
                NotificationApps.shared.byName.merge(index) { current, _ in current }
                NotificationApps.shared.indexing = false
            }
        }
    }

    func resolve(name: String) -> NotificationAppInfo {
        let key = Self.normalized(name)
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            guard let localized = $0.localizedName else { return false }
            return Self.normalized(localized) == key
        }), let bundleID = running.bundleIdentifier {
            return NotificationAppInfo(name: name, bundleID: bundleID, url: running.bundleURL)
        }
        if let known = byName[key] { return NotificationAppInfo(name: name, bundleID: known.bundleID, url: known.url) }
        if let bundleID = Self.wellKnown[key],
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NotificationAppInfo(name: name, bundleID: bundleID, url: url)
        }
        return NotificationAppInfo(name: name, bundleID: nil, url: nil)
    }

    func isMessaging(_ app: NotificationAppInfo) -> Bool {
        if let bundleID = app.bundleID { return Self.messagingApps.contains(bundleID) }
        return Self.messagingNames.contains(Self.normalized(app.name))
    }

    /// The app's real icon, cached.
    func icon(for app: NotificationAppInfo) -> NSImage? {
        if let cached = icons[app.key] { return cached }
        guard let url = app.url else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        icons[app.key] = icon
        return icon
    }

    /// The icon's main color, for the glow under the island and the count badge.
    func tint(for app: NotificationAppInfo) -> Color {
        if let cached = tints[app.key] { return cached }
        let color = icon(for: app).flatMap(Self.dominantColor) ?? Self.monogramColor(for: app.name)
        tints[app.key] = color
        return color
    }

    /// Apps that can send notifications on this Mac (from the system's notification settings),
    /// plus the ones Isla has already seen, for Settings › Notifications.
    func knownApps(including seen: [NotificationAppInfo]) -> [NotificationAppInfo] {
        var result: [String: NotificationAppInfo] = [:]
        for app in Self.systemNotificationApps() { result[app.key] = app }
        // Messaging apps that are installed but have not asked to notify yet.
        for bundleID in Self.messagingApps.union(["com.apple.mail", "com.microsoft.Outlook", "com.readdle.smartemail-Mac"])
        where result[bundleID] == nil {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                  url.path.hasPrefix("/Applications") || url.path.hasPrefix("/System/Applications") else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            result[bundleID] = NotificationAppInfo(name: name, bundleID: bundleID, url: url)
        }
        for app in seen where result[app.key] == nil { result[app.key] = app }
        return result.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Index

    private static let wellKnown: [String: String] = [
        "messages": "com.apple.MobileSMS", "mensajes": "com.apple.MobileSMS", "mail": "com.apple.mail",
        "correo": "com.apple.mail", "whatsapp": "net.whatsapp.WhatsApp", "facetime": "com.apple.FaceTime",
        "calendar": "com.apple.iCal", "calendario": "com.apple.iCal", "reminders": "com.apple.reminders",
        "recordatorios": "com.apple.reminders", "telegram": "ru.keepcoder.Telegram", "slack": "com.tinyspeck.slackmacgap",
        "discord": "com.hnc.Discord", "script editor": "com.apple.ScriptEditor2", "editor de scripts": "com.apple.ScriptEditor2",
    ]

    nonisolated static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    nonisolated private static func buildIndex() -> [String: NotificationAppInfo] {
        let fm = FileManager.default
        var folders = ["/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities",
                       "/Applications/Setapp", "/System/Library/CoreServices"]
        folders.append((NSHomeDirectory() as NSString).appendingPathComponent("Applications"))
        var urls: [URL] = []
        for folder in folders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            urls += names.filter { $0.hasSuffix(".app") }.map { URL(fileURLWithPath: folder).appendingPathComponent($0) }
        }
        urls += systemNotificationApps().compactMap(\.url)

        var index: [String: NotificationAppInfo] = [:]
        for url in urls {
            guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { continue }
            var names = [fm.displayName(atPath: url.path), url.deletingPathExtension().lastPathComponent]
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let name = bundle.localizedInfoDictionary?[key] as? String ?? bundle.infoDictionary?[key] as? String {
                    names.append(name)
                }
            }
            let info = NotificationAppInfo(name: fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                                           bundleID: bundleID, url: url)
            for name in names {
                let key = normalized(name.replacingOccurrences(of: ".app", with: ""))
                if !key.isEmpty, index[key] == nil { index[key] = info }
            }
        }
        return index
    }

    /// The apps listed in System Settings › Notifications, read from its preferences file.
    nonisolated private static func systemNotificationApps() -> [NotificationAppInfo] {
        guard let apps = CFPreferencesCopyAppValue("apps" as CFString, "com.apple.ncprefs" as CFString) as? [[String: Any]] else { return [] }
        let fm = FileManager.default
        return apps.compactMap { entry in
            guard let bundleID = entry["bundle-id"] as? String, !bundleID.hasPrefix("_SYSTEM_CENTER_"),
                  let path = entry["path"] as? String, path.hasSuffix(".app"),
                  !path.contains("/Contents/"), fm.fileExists(atPath: path) else { return nil }
            let name = fm.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
            return NotificationAppInfo(name: name, bundleID: bundleID, url: URL(fileURLWithPath: path))
        }
    }

    // MARK: Colors

    private static func dominantColor(of image: NSImage) -> Color? {
        let side = 12
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for index in 0..<(side * side) {
            let r = Double(data[index * 4]) / 255, g = Double(data[index * 4 + 1]) / 255
            let b = Double(data[index * 4 + 2]) / 255, a = Double(data[index * 4 + 3]) / 255
            guard a > 0.5 else { continue }
            let saturation = max(r, g, b) - min(r, g, b)
            let w = 0.05 + saturation * saturation
            red += r * w; green += g * w; blue += b * w; weight += w
        }
        guard weight > 0 else { return nil }
        let color = NSColor(red: red / weight, green: green / weight, blue: blue / weight, alpha: 1)
        // Keep it bright enough to read as a glow on black.
        let hsb = color.usingColorSpace(.deviceRGB) ?? color
        return Color(nsColor: NSColor(hue: hsb.hueComponent, saturation: min(1, hsb.saturationComponent * 1.1),
                                      brightness: max(0.75, hsb.brightnessComponent), alpha: 1))
    }

    static func monogramColor(for name: String) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .indigo, .red, .mint]
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}

/// The app's real icon, or a colored monogram for apps that only exist on the iPhone.
struct NotificationAppIcon: View {
    let app: NotificationAppInfo
    var fromiPhone = false
    var size: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let icon = NotificationApps.shared.icon(for: app) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                let tint = NotificationApps.monogramColor(for: app.name)
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        Text(verbatim: String(app.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: size * 0.86, height: size * 0.86)
                    .frame(width: size, height: size)
            }
            if fromiPhone {
                Image(systemName: "iphone")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(size * 0.06)
                    .background(Circle().fill(Color(white: 0.18)))
                    .offset(x: size * 0.12, y: size * 0.1)
            }
        }
        .accessibilityHidden(true)
    }
}
