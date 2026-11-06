//
//  NotificationMirror.swift
//  Isla
//
//  Shows the notifications of Messages, WhatsApp, Mail and every other app in the notch.
//  The banners come from `NotificationCenterReader`; this decides how they appear: one at a
//  time out of the camera, stacked when several arrive, grouped when they belong to the same
//  conversation, held while the pointer rests on them, dismissed with a swipe, and opened
//  with a click. Everything stays in memory on this Mac.
//

import AppKit
import SwiftUI

struct IslaNotification: Identifiable, Equatable, Hashable, Sendable {
    var id: String
    /// The system banner it mirrors, to open its conversation or close it.
    var bannerID: String?
    var app: NotificationAppInfo
    var title: String
    var subtitle: String
    var body: String
    var fromiPhone: Bool
    /// Someone writing to you (Messages, WhatsApp…), as opposed to an app's notice.
    var isMessage: Bool
    var date: Date
    /// Messages of the same conversation folded into this one.
    var count = 1

    /// Who it is from, or the app when the banner has no title.
    var sender: String { title.isEmpty ? app.name : title }
}

@Observable
@MainActor
final class NotificationMirror {
    static let shared = NotificationMirror()

    enum Status: Equatable { case off, needsAccess, running }
    enum Exit: Equatable { case up, left, right, fade }

    private(set) var status: Status = .off
    /// Recent notifications, newest first. Only in memory: nothing is written to disk.
    private(set) var history: [IslaNotification] = []
    /// What the island is showing right now, newest first: the first one is in front and up
    /// to two more peek out underneath it.
    private(set) var burst: [IslaNotification] = []
    /// Bumped for every arrival, so the island can give its nudge.
    private(set) var arrivals = 0
    /// Which way the notification on screen leaves when it goes.
    private(set) var exit: Exit = .fade
    /// Apps seen so far (names and bundle IDs only), for Settings.
    private(set) var seenApps: [NotificationAppInfo] = []

    @ObservationIgnored private let reader = NotificationCenterReader()
    @ObservationIgnored private var accessObserver: NSObjectProtocol?
    @ObservationIgnored private var activeObserver: NSObjectProtocol?
    @ObservationIgnored private var sequence = 0

    private static let seenAppsKey = "notificationsSeenApps"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.seenAppsKey),
           let apps = try? JSONDecoder().decode([NotificationAppInfo].self, from: data) {
            seenApps = apps
        }
        reader.onBanner = { [weak self] banner in self?.receive(banner) }
    }

    // MARK: Running

    /// Starts or stops reading banners to match the setting and the Accessibility grant.
    func refresh() {
        guard Preferences.shared.notificationsEnabled else {
            reader.stop()
            status = .off
            return
        }
        watchForAccessChanges()
        guard AXIsProcessTrusted() else {
            reader.stop()
            status = .needsAccess
            return
        }
        NotificationApps.shared.prepare()
        reader.start()
        status = reader.isRunning ? .running : .needsAccess
    }

    /// The Accessibility list has no API to observe, but the system broadcasts a note when it
    /// changes, and Isla re-checks whenever it comes to the front. No polling.
    private func watchForAccessChanges() {
        guard accessObserver == nil else { return }
        accessObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated { NotificationMirror.shared.refresh() }
            }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                if NotificationMirror.shared.status == .needsAccess { NotificationMirror.shared.refresh() }
            }
        }
    }

    // MARK: Arrivals

    private func receive(_ banner: NotificationBanner) {
        let app = NotificationApps.shared.resolve(name: banner.appName)
        // Isla's own banners (and its Debug twin's) are already in the notch.
        if app.bundleID?.hasPrefix("com.kyrossolutions.isla") == true { return }
        noteSeen(app)
        guard !Preferences.shared.notificationsMutedApps.contains(app.key) else { return }
        if banner.isUpdate, let index = burst.firstIndex(where: { $0.bannerID == banner.id }) {
            // The banner was read before it was complete: fill in the card already shown.
            burst[index].title = banner.title
            burst[index].subtitle = banner.subtitle
            burst[index].body = banner.body
            if let entry = history.firstIndex(where: { $0.bannerID == banner.id }) {
                history[entry].title = banner.title
                history[entry].subtitle = banner.subtitle
                history[entry].body = banner.body
            }
            if index == 0, LiveActivityCenter.shared.isPresentingNotification {
                LiveActivityCenter.shared.post(.notification(burst[0], stack: min(burst.count - 1, 2)),
                                               duration: Self.duration(for: burst[0]))
            }
            return
        }
        let notification = IslaNotification(id: nextID(), bannerID: banner.id, app: app, title: banner.title,
                                            subtitle: banner.subtitle, body: banner.body, fromiPhone: banner.fromiPhone,
                                            isMessage: NotificationApps.shared.isMessaging(app), date: .now)
        present(notification, closeBanner: !banner.isAlert)
    }

    /// Puts a notification on the island (and in the recent list).
    func present(_ notification: IslaNotification, closeBanner: Bool = false) {
        let prefs = Preferences.shared
        let center = LiveActivityCenter.shared
        if !center.isPresentingNotification { burst.removeAll() }

        var shown = notification
        if let front = burst.first, front.app.key == shown.app.key, front.title == shown.title {
            // The same conversation: one card that counts its messages.
            shown.count = front.count + 1
            burst[0] = shown
        } else {
            burst.insert(shown, at: 0)
            if burst.count > 6 { burst.removeLast() }
        }

        if prefs.notificationsHistory {
            history.insert(notification, at: 0)
            if history.count > 40 { history.removeLast(history.count - 40) }
        }

        exit = .fade
        arrivals &+= 1
        center.post(.notification(shown, stack: min(burst.count - 1, 2)), duration: Self.duration(for: shown))

        if !prefs.notificationsSound.isEmpty {
            NSSound(named: NSSound.Name(prefs.notificationsSound))?.play()
        }
        if closeBanner, prefs.notificationsHideBanner, let bannerID = notification.bannerID, NotchManager.shared.isNotchVisible {
            // The notch shows it now: close the system's copy. (Only when the notch can be
            // seen, so a notification is never lost behind a full-screen app.)
            reader.perform(.close, on: bannerID)
        }
    }

    private static func duration(for notification: IslaNotification) -> TimeInterval {
        let length = notification.subtitle.count + notification.body.count
        return length > 90 ? 7.5 : 6
    }

    private func nextID() -> String {
        sequence &+= 1
        return "notification-\(sequence)"
    }

    private func noteSeen(_ app: NotificationAppInfo) {
        guard !seenApps.contains(where: { $0.key == app.key }) else { return }
        seenApps.append(app)
        if let data = try? JSONEncoder().encode(seenApps) {
            UserDefaults.standard.set(data, forKey: Self.seenAppsKey)
        }
    }

    // MARK: Actions

    /// A click: straight to the conversation (through the system banner while it is still
    /// there), or else the app itself.
    func open(_ notification: IslaNotification) {
        dismiss(.fade)
        Haptics.tap()
        // Going to the app: the Nook steps aside.
        NotchManager.shared.closeAll()
        guard let bannerID = notification.bannerID else {
            launch(notification.app)
            return
        }
        reader.perform(.open, on: bannerID) { [weak self] opened in
            if !opened { self?.launch(notification.app) }
        }
    }

    func launch(_ app: NotificationAppInfo) {
        guard let url = app.url ?? app.bundleID.flatMap({ NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Sends the notification on screen away: up into the camera or off to a side.
    func dismiss(_ direction: Exit) {
        guard LiveActivityCenter.shared.isPresentingNotification else { return }
        exit = direction
        // Let the island pick up the direction before the notification leaves.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                LiveActivityCenter.shared.dismissTransient()
                NotificationMirror.shared.burst.removeAll()
            }
        }
    }

    /// Resting the pointer on a notification keeps it (and reveals it when content is hidden).
    func setHovering(_ hovering: Bool) {
        LiveActivityCenter.shared.holdTransient(hovering)
    }

    func clearHistory() {
        history.removeAll()
    }

    func remove(_ notification: IslaNotification) {
        history.removeAll { $0.id == notification.id }
    }

    // MARK: Samples

    /// A sample from Isla itself, for the button in Settings.
    func preview() {
        let isla = NotificationAppInfo(name: "Isla", bundleID: Bundle.main.bundleIdentifier, url: Bundle.main.bundleURL)
        present(IslaNotification(id: nextID(), bannerID: nil, app: isla, title: "Isla",
                                 subtitle: String(localized: "Notifications in the notch"),
                                 body: String(localized: "This is how a message looks when it arrives. Click to open it, or swipe it away."),
                                 fromiPhone: false, isMessage: true, date: .now))
    }

    #if DEBUG
    /// `isla-dev://demo/notify-…`: sample notifications in memory, to preview the island.
    func runDemo(_ name: String) {
        let apps = NotificationApps.shared
        apps.prepare()
        func make(_ appName: String, _ title: String, _ subtitle: String, _ body: String, iPhone: Bool = false) -> IslaNotification {
            let app = apps.resolve(name: appName)
            return IslaNotification(id: nextID(), bannerID: nil, app: app, title: title, subtitle: subtitle, body: body,
                                    fromiPhone: iPhone, isMessage: apps.isMessaging(app) || appName == "Messages", date: .now)
        }
        let messages = FileManager.default.displayName(atPath: "/System/Applications/Messages.app").replacingOccurrences(of: ".app", with: "")
        let mail = FileManager.default.displayName(atPath: "/System/Applications/Mail.app").replacingOccurrences(of: ".app", with: "")
        switch name {
        case "notify-messages":
            present(make(messages, "Ana García", "", "¿Comemos a la una? Tengo una mesa en el Malecón 🌴"))
        case "notify-whatsapp":
            present(make("WhatsApp", "Familia 🇩🇴", "Luis", "Ya llegué a casa, mañana les paso las fotos del viaje"))
        case "notify-mail":
            present(make(mail, "Kyros Solutions", "Factura de noviembre", "Hola Jonathan, te adjunto la factura del mes. Cualquier duda me avisas y lo revisamos el lunes en la reunión."))
        case "notify-iphone":
            present(make("Instagram", "itsqueenbebaaa", "", "Te envió una publicación", iPhone: true))
        case "notify-burst":
            let samples = [make("WhatsApp", "Familia 🇩🇴", "Luis", "Ya llegué a casa"),
                           make("WhatsApp", "Familia 🇩🇴", "Marta", "¡Qué bueno! Descansa"),
                           make(messages, "Ana García", "", "¿Sigue en pie lo de mañana?"),
                           make(mail, "GitHub", "[isla] Nueva estrella", "Alguien marcó Kyros-Solutions-RD/isla con una estrella.")]
            Task { @MainActor in
                for sample in samples {
                    self.present(sample)
                    try? await Task.sleep(for: .seconds(1.6))
                }
            }
        case "notify-up": dismiss(.up)
        case "notify-left": dismiss(.left)
        case "notify-right": dismiss(.right)
        case "notify-hold", "notify-release":
            // The pointer resting on the island, without moving the real pointer.
            let hold = name == "notify-hold"
            for controller in NotchManager.shared.controllers.values {
                controller.model.isHovering = hold
                hold ? controller.model.peek() : controller.model.unpeek()
            }
            setHovering(hold)
        case "notify-private": Preferences.shared.notificationsHideContent = true
        case "notify-public": Preferences.shared.notificationsHideContent = false
        case "notify-history":
            for (index, sample) in [make(mail, "GitHub", "[isla] Nueva estrella", "Alguien marcó el repositorio con una estrella."),
                                    make("WhatsApp", "Familia 🇩🇴", "Luis", "Ya llegué a casa"),
                                    make(messages, "Ana García", "", "¿Comemos a la una?")].enumerated() {
                var item = sample
                item.date = .now.addingTimeInterval(-Double(3 - index) * 420)
                history.insert(item, at: 0)
            }
        default: break
        }
    }
    #endif
}

// MARK: - Layout

/// Sizes of the island while it shows a notification. The island's shape and its content
/// read the same numbers, so the text always fits the silhouette exactly.
enum NotificationLayout {
    static let iconSize: CGFloat = 22
    static let iconGap: CGFloat = 7
    static let earInset: CGFloat = 12
    static let lineHeight: CGFloat = 15
    static let subtitleHeight: CGFloat = 16
    static let nameFont = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    static let bodyFont = NSFont.systemFont(ofSize: 12, weight: .regular)

    /// The first line under the camera: the sender, or the app while the content is hidden.
    static func earLabel(for notification: IslaNotification, revealed: Bool) -> String {
        revealed ? notification.sender : notification.app.name
    }

    static func earWidth(for notification: IslaNotification, revealed: Bool) -> CGFloat {
        let label = earLabel(for: notification, revealed: revealed) as NSString
        let text = ceil(label.size(withAttributes: [.font: nameFont]).width)
        return min(214, max(132, earInset + iconSize + iconGap + text + 12))
    }

    /// Where the detail text starts: under the sender's name.
    static var detailLeading: CGFloat { earInset + iconSize + iconGap }

    @MainActor
    static func bodyLines(for notification: IslaNotification, width: CGFloat, expanded: Bool) -> Int {
        guard !notification.body.isEmpty, width > 20 else { return 0 }
        let limit = expanded ? 5 : (notification.subtitle.isEmpty ? 2 : 1)
        return min(max(1, wrappedLines(notification.body, width: width)), limit)
    }

    /// Lines the text takes at this width, counted by TextKit (emoji and long words included).
    @MainActor private static var lineCache: [String: Int] = [:]

    @MainActor
    static func wrappedLines(_ text: String, width: CGFloat) -> Int {
        let key = "\(Int(width))|\(text)"
        if let cached = lineCache[key] { return cached }
        let storage = NSTextStorage(string: text, attributes: [.font: bodyFont])
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        var lines = 0, index = 0
        while index < manager.numberOfGlyphs, lines < 12 {
            var range = NSRange()
            manager.lineFragmentRect(forGlyphAt: index, effectiveRange: &range)
            index = NSMaxRange(range)
            lines += 1
        }
        if lineCache.count > 200 { lineCache.removeAll() }
        lineCache[key] = lines
        return lines
    }

    @MainActor
    static func detailHeight(for notification: IslaNotification, islandWidth: CGFloat, revealed: Bool, expanded: Bool) -> CGFloat {
        guard revealed else { return 0 }
        let width = islandWidth - detailLeading - 18
        let lines = bodyLines(for: notification, width: width, expanded: expanded)
        let subtitle: CGFloat = notification.subtitle.isEmpty ? 0 : subtitleHeight
        guard lines > 0 || subtitle > 0 else { return 0 }
        return 1 + subtitle + CGFloat(lines) * lineHeight + 12
    }
}

extension LiveActivityCenter {
    var isPresentingNotification: Bool {
        if case .notification? = transient?.kind { return true }
        return false
    }
}

extension LiveActivityKind {
    var notification: IslaNotification? {
        if case .notification(let notification, _) = self { return notification }
        return nil
    }
}
