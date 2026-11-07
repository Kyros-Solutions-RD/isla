//
//  NotificationCenterReader.swift
//  Isla
//
//  macOS has no public way to read another app's notifications, but Notification Center
//  describes every banner it draws to Accessibility (the same permission Isla already uses
//  for the volume overlay). This reader observes that process and reports each new banner:
//  the app, the title, the subtitle and the text. Nothing is read from disk and nothing
//  leaves the Mac.
//
//  What the tree looks like on macOS 26–27 (inspected with a walker before writing this):
//  a window with the subrole `AXSystemDialog` holds, while a banner shows, groups with the
//  subrole `AXNotificationCenterBanner` (or `…BannerStack`), an identifier per notification
//  and three texts identified `title`, `subtitle` and `body`. Their description reads
//  "App, title, subtitle, body[, from iPhone]". When the Notification Center list is open,
//  the same window holds a group identified `AXNotificationListItems` with every notification
//  of the day: that list is never mistaken for new banners.
//

import AppKit
import ApplicationServices

/// One banner as Notification Center describes it.
struct NotificationBanner: Sendable, Equatable {
    var id: String
    var appName: String
    var title: String
    var subtitle: String
    var body: String
    /// Mirrored from the iPhone ("…, from iPhone").
    var fromiPhone: Bool
    /// Alerts stay until you answer them and carry their own buttons: Isla never closes them.
    var isAlert: Bool
    /// The same banner, filled in after it was first read (its text grew): not a new message.
    var isUpdate = false
    /// The names of its buttons ("Accept", "Decline"…), in the system's language.
    var buttons: [String] = []
}

final class NotificationCenterReader: @unchecked Sendable {
    static let bundleID = "com.apple.notificationcenterui"

    /// Called on the main thread for each new banner.
    var onBanner: (@MainActor (NotificationBanner) -> Void)?
    /// Called on the main thread with the banners that left the screen (answered, declined,
    /// or timed out), so an incoming call can leave the island with them.
    var onGone: (@MainActor (Set<String>) -> Void)?

    // Lifecycle (main thread).
    private var observer: AXObserver?
    private var launchObserver: NSObjectProtocol?

    // Scanning (all on `queue`).
    private let queue = DispatchQueue(label: "Isla.NotificationReader", qos: .userInitiated)
    private var appElement: AXUIElement?
    private var scanPending = false
    private var hasBaseline = false
    /// Banner identifier → what it said, so an updated banner counts once more and the
    /// same banner never twice.
    private var seen: [String: String] = [:]
    private var seenOrder: [String] = []
    /// The banners still on screen, to open or close them on request.
    private var elements: [String: AXUIElement] = [:]
    private var elementOrder: [String] = []
    private var quietUntil: TimeInterval = 0
    /// Banners on screen at the last scan.
    private var onScreen: Set<String> = []

    var isRunning: Bool { observer != nil }

    // MARK: Start & stop (main thread)

    @MainActor
    func start() {
        guard observer == nil else { return }
        attach()
        if launchObserver == nil {
            // Notification Center can restart (after a crash or an update): follow it.
            launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == Self.bundleID else { return }
                MainActor.assumeIsolated {
                    guard let self, self.launchObserver != nil else { return }
                    self.detach()
                    self.attach()
                }
            }
        }
    }

    @MainActor
    func stop() {
        detach()
        if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
        launchObserver = nil
    }

    @MainActor
    private func attach() {
        guard AXIsProcessTrusted(),
              let process = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first else { return }
        let pid = process.processIdentifier
        let app = AXUIElementCreateApplication(pid)
        // A busy Notification Center must never hold Isla up.
        AXUIElementSetMessagingTimeout(app, 0.4)

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<NotificationCenterReader>.fromOpaque(refcon).takeUnretainedValue().scheduleScan()
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXCreatedNotification, kAXLayoutChangedNotification] {
            AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        // Common modes: banners keep arriving while a menu is open.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        let element = ElementBox(value: app)
        queue.async {
            self.appElement = element.value
            self.hasBaseline = false
            self.scan()
        }
    }

    @MainActor
    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        queue.async {
            self.appElement = nil
            self.elements.removeAll()
            self.elementOrder.removeAll()
        }
    }

    // MARK: Acting on a banner

    enum BannerAction: Sendable {
        case open, close
        /// Presses the banner's button with one of these names (an incoming call's Accept).
        case button([String])
    }

    /// Opens (like a click on the banner, which goes straight to the conversation) or closes a
    /// banner that is still on screen. Reports on the main thread whether it worked.
    func perform(_ action: BannerAction, on id: String, completion: (@MainActor (Bool) -> Void)? = nil) {
        queue.async {
            var done = false
            if let element = self.elements[id] {
                switch action {
                case .open:
                    done = AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
                case .close:
                    if let close = Self.closeAction(of: element) {
                        done = AXUIElementPerformAction(element, close as CFString) == .success
                    }
                case .button(let names):
                    if let button = Self.button(in: element, named: names) {
                        done = AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
                    }
                }
                if done { self.forget(id) }
            }
            if let completion {
                DispatchQueue.main.async { MainActor.assumeIsolated { completion(done) } }
            }
        }
    }

    /// Banners offer "Show details", "Show" and "Close" as custom actions, named in the
    /// system's language. The close one is matched by name, or else it is the last one.
    private static func closeAction(of element: AXUIElement) -> String? {
        var names: CFArray?
        AXUIElementCopyActionNames(element, &names)
        let custom = ((names as? [String]) ?? []).filter { $0.hasPrefix("Name:") }
        let words = ["Close", "Cerrar", "Fermer", "Schließen", "Chiudi", "Fechar", "Sluiten", "Stäng", "Luk", "Lukk",
                     "Sulje", "Zamknij", "Kapat", "Закрыть", "閉じる", "关闭", "關閉", "닫기"]
        return custom.first { action in words.contains { action.hasPrefix("Name:\($0)\n") } } ?? custom.last
    }

    /// A button inside a banner whose title or description starts with one of `names`.
    private static func button(in element: AXUIElement, named names: [String], depth: Int = 0) -> AXUIElement? {
        guard depth < 4 else { return nil }
        for child in children(of: element, kAXChildrenAttribute) {
            if string(child, kAXRoleAttribute) == kAXButtonRole {
                let label = (string(child, kAXTitleAttribute) ?? "") + " " + (string(child, kAXDescriptionAttribute) ?? "")
                if names.contains(where: { label.localizedCaseInsensitiveContains($0) }) { return child }
            }
            if let found = button(in: child, named: names, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func buttonNames(in element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 4 else { return [] }
        var names: [String] = []
        for child in children(of: element, kAXChildrenAttribute) {
            if string(child, kAXRoleAttribute) == kAXButtonRole {
                let label = [string(child, kAXTitleAttribute), string(child, kAXDescriptionAttribute)]
                    .compactMap { $0 }.first { !$0.isEmpty }
                if let label { names.append(label) }
            } else {
                names += buttonNames(in: child, depth: depth + 1)
            }
        }
        return names
    }

    // MARK: Scanning (queue)

    /// Notification Center reports many layout changes while a banner slides in; one scan
    /// a few milliseconds later covers them all.
    private func scheduleScan() {
        queue.async {
            guard !self.scanPending else { return }
            self.scanPending = true
            let now = ProcessInfo.processInfo.systemUptime
            // While the Notification Center list is open and scrolling, look less often.
            let delay = now < self.quietUntil ? 0.35 : 0.03
            self.queue.asyncAfter(deadline: .now() + delay) {
                self.scanPending = false
                self.scan()
            }
        }
    }

    private func scan() {
        guard let app = appElement else { return }
        var banners: [AXUIElement] = []
        var listOpen = false
        for window in Self.children(of: app, kAXWindowsAttribute) where Self.string(window, kAXSubroleAttribute) == "AXSystemDialog" {
            collect(window, depth: 0, into: &banners, listOpen: &listOpen)
            if listOpen { break }
        }
        if listOpen {
            // Notification Center's own list: nothing in it is new.
            quietUntil = ProcessInfo.processInfo.systemUptime + 1
            hasBaseline = true
            return
        }

        let present = Set(banners.compactMap { Self.string($0, kAXIdentifierAttribute) })
        let gone = onScreen.subtracting(present)
        onScreen = present
        if !gone.isEmpty {
            for id in gone { forget(id) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.onGone?(gone) }
            }
        }

        var fresh: [NotificationBanner] = []
        for element in banners {
            guard var banner = Self.read(element) else { continue }
            let signature = [banner.title, banner.subtitle, banner.body].joined(separator: "\u{1F}")
            let previous = seen[banner.id]
            guard previous != signature else { continue }
            if previous == nil { seenOrder.append(banner.id) }
            seen[banner.id] = signature
            // A banner whose text only grew is the same message, completed.
            if let previous, signature.hasPrefix(previous) || previous.allSatisfy({ $0 == "\u{1F}" }) {
                banner.isUpdate = true
            }
            if seenOrder.count > 300 {
                for old in seenOrder.prefix(100) { seen[old] = nil }
                seenOrder.removeFirst(100)
            }
            remember(element, for: banner.id)
            // Banners already on screen when Isla starts are not news.
            if hasBaseline { fresh.append(banner) }
        }
        hasBaseline = true
        guard !fresh.isEmpty else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                for banner in fresh { self.onBanner?(banner) }
            }
        }
    }

    private func collect(_ element: AXUIElement, depth: Int, into banners: inout [AXUIElement], listOpen: inout Bool) {
        guard depth < 8, !listOpen else { return }
        if Self.string(element, kAXIdentifierAttribute) == "AXNotificationListItems" {
            listOpen = true
            return
        }
        if Self.string(element, kAXSubroleAttribute)?.hasPrefix("AXNotificationCenter") == true {
            banners.append(element)
            return
        }
        if Self.string(element, kAXRoleAttribute) == kAXMenuBarRole { return }
        for child in Self.children(of: element, kAXChildrenAttribute) {
            collect(child, depth: depth + 1, into: &banners, listOpen: &listOpen)
        }
    }

    private func remember(_ element: AXUIElement, for id: String) {
        if elements[id] == nil { elementOrder.append(id) }
        elements[id] = element
        if elementOrder.count > 24 {
            let old = elementOrder.removeFirst()
            elements[old] = nil
        }
    }

    private func forget(_ id: String) {
        elements[id] = nil
        elementOrder.removeAll { $0 == id }
    }

    /// Reads one banner's texts and works out which app sent it.
    static func read(_ element: AXUIElement) -> NotificationBanner? {
        guard let id = string(element, kAXIdentifierAttribute), !id.isEmpty else { return nil }
        var title = "", subtitle = "", body = ""
        var hasButtons = false
        for child in children(of: element, kAXChildrenAttribute) {
            let role = string(child, kAXRoleAttribute)
            if role == kAXStaticTextRole {
                let value = string(child, kAXValueAttribute) ?? ""
                switch string(child, kAXIdentifierAttribute) {
                case "title": title = value
                case "subtitle": subtitle = value
                case "body": body = value
                default: break
                }
            } else if role == kAXButtonRole {
                hasButtons = true
            }
        }
        guard !(title.isEmpty && body.isEmpty) else { return nil }
        let description = string(element, kAXDescriptionAttribute) ?? ""
        let subrole = string(element, kAXSubroleAttribute) ?? ""
        let parsed = parse(description: description, title: title, subtitle: subtitle, body: body)
        var app = parsed.app
        if app.isEmpty || id.hasPrefix("ReminderManager") && app == title {
            app = id.hasPrefix("ReminderManager") ? NotificationApps.remindersName : app
        }
        return NotificationBanner(id: id, appName: app, title: title, subtitle: subtitle, body: body,
                                  fromiPhone: parsed.fromiPhone,
                                  isAlert: hasButtons || subrole.localizedCaseInsensitiveContains("alert"),
                                  buttons: buttonNames(in: element))
    }

    /// "Messages, Ana, Lunch?, from iPhone" → ("Messages", fromiPhone: true).
    static func parse(description: String, title: String, subtitle: String, body: String) -> (app: String, fromiPhone: Bool) {
        var app = ""
        if !title.isEmpty, let range = description.range(of: ", " + title) {
            app = String(description[..<range.lowerBound])
        } else if let first = description.components(separatedBy: ", ").first {
            app = first
        }
        var tail = ""
        let last = [body, subtitle, title].first { !$0.isEmpty } ?? ""
        if !last.isEmpty, let range = description.range(of: last, options: .backwards) {
            tail = String(description[range.upperBound...])
        }
        return (app.trimmingCharacters(in: .whitespaces), tail.contains("iPhone"))
    }

    // MARK: AX helpers

    /// Accessibility elements are safe to use from any thread; this lets one cross to the queue.
    private struct ElementBox: @unchecked Sendable { let value: AXUIElement }

    private static func value(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    private static func children(of element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        (value(element, attribute) as? [AXUIElement]) ?? []
    }
}
