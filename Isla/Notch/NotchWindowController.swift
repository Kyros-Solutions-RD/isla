//
//  NotchWindowController.swift
//  Isla
//
//  Owns the transparent panel that sits over the menu bar on one display. The
//  panel ignores the mouse everywhere except over the notch silhouette, so it
//  never steals clicks from the menu bar or the apps underneath.
//

import AppKit
import SwiftTerm
import SwiftUI

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

@MainActor
final class NotchWindowController {
    private(set) var screen: NSScreen
    let model: NotchViewModel
    let panel: NotchPanel

    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var yieldReturnTask: Task<Void, Never>?
    private var dragChangeCount = 0
    private var openedByDrag = false
    private var scrollAccumulator = CGSize.zero
    private var scrollConsumed = false
    private var shake = ShakeDetector()

    /// Largest panel we can ever draw, plus room for the shadow.
    private static let canvasSize = CGSize(width: 1040, height: 400)

    init(screen: NSScreen) {
        self.screen = screen
        let geometry = NotchGeometry.make(for: screen)
        self.model = NotchViewModel(displayID: screen.displayID, geometry: geometry)
        self.panel = NotchPanel(contentRect: NotchWindowController.frame(for: geometry))
        model.controller = self

        let root = NotchRootView(model: model)
        let hosting = NotchHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()

        installMonitors()
    }

    deinit {
        MainActor.assumeIsolated {
            for monitor in monitors { NSEvent.removeMonitor(monitor) }
            panel.orderOut(nil)
        }
    }

    private static func frame(for geometry: NotchGeometry) -> NSRect {
        let size = canvasSize
        return NSRect(x: geometry.centerX - size.width / 2,
                      y: geometry.topY - size.height,
                      width: size.width,
                      height: size.height)
    }

    func update(screen: NSScreen) {
        self.screen = screen
        let geometry = NotchGeometry.make(for: screen)
        model.geometry = geometry
        panel.setFrame(NotchWindowController.frame(for: geometry), display: true)
    }

    func setHidden(_ hidden: Bool) {
        if hidden {
            model.close()
            panel.orderOut(nil)
        } else if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Opening & closing

    func open(_ tab: NotchTab? = nil, makeKey: Bool = false) {
        cancelTimers()
        model.open(tab)
        panel.ignoresMouseEvents = false
        if makeKey {
            panel.makeKey()
        }
    }

    func close() {
        cancelTimers()
        openedByDrag = false
        let wasKey = panel.isKeyWindow
        model.close()
        if wasKey { relinquishKeyFocus() }
        evaluatePointer()
    }

    func toggle(_ tab: NotchTab? = nil) {
        if model.isOpen && (tab == nil || tab == model.tab) {
            close()
        } else {
            open(tab, makeKey: true)
        }
    }

    /// Gives keyboard focus back to the app the user was working in.
    private func relinquishKeyFocus() {
        panel.makeFirstResponder(nil)
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    private func cancelTimers() {
        hoverTask?.cancel()
        closeTask?.cancel()
    }

    // MARK: - Pointer tracking

    private var interactiveRect: CGRect {
        let geometry = model.geometry
        switch model.phase {
        case .open:
            return geometry.rect(for: model.openSize).insetBy(dx: -6, dy: -6)
        case .peek, .closed:
            var rect = geometry.rect(for: model.shapeSize).insetBy(dx: -10, dy: 0)
            rect.origin.y -= 4
            rect.size.height += 8
            return rect
        }
    }

    private var dragAttractionRect: CGRect {
        model.geometry.rect(for: model.closedSize).insetBy(dx: -90, dy: -70)
    }

    private func installMonitors() {
        let pointerEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown, .leftMouseUp]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: pointerEvents, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleGlobal(event) }
        }) { monitors.append(global) }

        if let local = NSEvent.addLocalMonitorForEvents(matching: pointerEvents, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.evaluatePointer() }
            return event
        }) { monitors.append(local) }

        if let scroll = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleScroll(event) }
            return consumed ? nil : event
        }) { monitors.append(scroll) }

        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleKey(event) }
            return consumed ? nil : event
        }) { monitors.append(keys) }
    }

    private func handleGlobal(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            dragChangeCount = NSPasteboard(name: .drag).changeCount
            shake.reset()
            if model.isOpen && !model.isPinned && !interactiveRect.contains(NSEvent.mouseLocation) {
                close()
                return
            }
        case .leftMouseDragged:
            handleDrag()
        case .leftMouseUp:
            endDrag()
        default:
            break
        }
        evaluatePointer()
    }

    func evaluatePointer() {
        let location = NSEvent.mouseLocation
        // Decided first: on the menu bar beside the camera the pointer is on its way to a menu
        // or an icon, so it does not wake the island (even one already peeking: it settles).
        let yielding = updateYield(at: location)
        let inside = !yielding && (interactiveRect.contains(location) || (model.isDraggingFiles && dragAttractionRect.contains(location)))
        // The bubble of a second activity takes clicks, but resting on it does not open the Nook.
        let onBubble = model.secondaryBubbleRect?.contains(location) ?? false
        if panel.ignoresMouseEvents == (inside || onBubble) {
            panel.ignoresMouseEvents = !(inside || onBubble)
        }
        guard inside != model.isHovering else { return }
        model.isHovering = inside
        inside ? pointerEntered() : pointerExited()
    }

    // MARK: - Making way for the menu bar

    /// With the pointer on the menu bar beside the island (on its way to a menu or an icon of
    /// another app), the ears of an ongoing activity tuck into the camera, so what was under
    /// them can be seen and clicked. They come back once the pointer leaves the menu bar.
    /// Resting on the camera itself still brings the island out as usual.
    @discardableResult
    private func updateYield(at location: CGPoint) -> Bool {
        let yield = shouldYield(at: location)
        if yield {
            yieldReturnTask?.cancel()
            yieldReturnTask = nil
            if !model.isYielding { model.isYielding = true }
        } else if model.isYielding, yieldReturnTask == nil {
            yieldReturnTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(420))
                guard let self, !Task.isCancelled else { return }
                self.yieldReturnTask = nil
                if !self.shouldYield(at: NSEvent.mouseLocation) { self.model.isYielding = false }
            }
        }
        return yield
    }

    private func shouldYield(at location: CGPoint) -> Bool {
        let activities = LiveActivityCenter.shared
        guard Preferences.shared.activityYieldToMenuBar, model.phase != .open, !model.isDraggingFiles,
              activities.transient == nil, let activity = activities.presented?.kind else { return false }
        let geometry = model.geometry
        // The menu bar band, plus the few points under the island that already count as on it.
        let band = geometry.notchSize.height + 6
        guard location.y > geometry.topY - band, location.y <= geometry.topY + 1 else { return false }
        // The camera (and the margin that wakes the island) is the island's own handle.
        let camera = geometry.rect(for: geometry.notchSize).insetBy(dx: -10, dy: 0)
        if location.x >= camera.minX && location.x <= camera.maxX { return false }
        // Anywhere the ears (or the bubble beside them) would cover, with a little lead so they
        // are already gone when the pointer gets there along the bar.
        let full = model.fullClosedSize(for: activity, compact: model.showsCompactEars)
        var reach = full.width / 2 + 36
        if activities.secondary != nil { reach += NotchViewModel.bubbleGap + geometry.notchSize.height + 10 }
        return abs(location.x - geometry.centerX) <= reach
    }

    private func pointerEntered() {
        closeTask?.cancel()
        guard model.phase != .open else { return }
        // Arriving along the menu bar from beside the island, the pointer is most likely
        // passing through to the other side: the island waits a moment before it wakes,
        // instead of popping its ears out under a pointer that is just crossing.
        if model.isYielding {
            hoverTask?.cancel()
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard let self, !Task.isCancelled, self.model.isHovering, self.model.phase != .open else { return }
                self.wake()
            }
            return
        }
        wake()
    }

    private func wake() {
        model.peek()
        if LiveActivityCenter.shared.isPresentingNotification {
            // Resting on a notification keeps it and unfolds it, so it can be read and clicked;
            // it does not turn into the Nook under the pointer (swipe down for that).
            NotificationMirror.shared.setHovering(true)
            return
        }
        let prefs = Preferences.shared
        guard prefs.openOnHover else { return }
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(prefs.hoverDelay))
            guard let self, !Task.isCancelled, self.model.isHovering else { return }
            self.open()
        }
    }

    private func pointerExited() {
        hoverTask?.cancel()
        NotificationMirror.shared.setHovering(false)
        if model.phase == .peek {
            model.unpeek()
            return
        }
        guard model.isOpen, Preferences.shared.closeOnMouseExit, !model.isPinned, !model.isDraggingFiles else { return }
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard let self, !Task.isCancelled, !self.model.isHovering else { return }
            guard self.model.holds.isEmpty, !self.isEditingText else { return }
            self.close()
        }
    }

    private var isEditingText: Bool {
        panel.isKeyWindow && (panel.firstResponder is NSTextView || panel.firstResponder is TerminalView)
    }

    private var isTerminalFocused: Bool {
        panel.isKeyWindow && panel.firstResponder is TerminalView
    }

    // MARK: - Dragging files onto the notch

    private func handleDrag() {
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragChangeCount else { return }
        let types = pasteboard.types ?? []
        let carriesContent = types.contains(.fileURL) || types.contains(.URL) || types.contains(.png) ||
            types.contains(.tiff) || types.contains(.string)
        guard carriesContent else { return }

        if !model.isDraggingFiles {
            model.isDraggingFiles = true
        }

        let location = NSEvent.mouseLocation
        if Preferences.shared.pocketEnabled, types.contains(.fileURL), shake.register(location) {
            PocketController.shared.present(at: location)
        }

        guard Preferences.shared.openShelfOnDrag, dragAttractionRect.contains(location) else { return }
        panel.ignoresMouseEvents = false
        if !model.isOpen {
            openedByDrag = true
            open(.shelf)
        } else if model.tab != .shelf && !model.isDropTargeted {
            model.select(.shelf)
        }
    }

    private func endDrag() {
        guard model.isDraggingFiles else { return }
        model.isDraggingFiles = false
        shake.reset()
        if openedByDrag {
            openedByDrag = false
            // Leave the shelf visible briefly so the user sees the drop land.
            closeTask?.cancel()
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.4))
                guard let self, !Task.isCancelled, !self.model.isHovering else { return }
                self.close()
            }
        }
    }

    // MARK: - Gestures

    private func handleScroll(_ event: NSEvent) -> Bool {
        guard event.window === panel, Preferences.shared.gesturesEnabled else { return false }

        if event.phase == .began || event.phase == .mayBegin {
            scrollAccumulator = .zero
            scrollConsumed = false
        }
        // Normalize so positive values follow the fingers (down / right).
        let inverted = event.isDirectionInvertedFromDevice
        let dy = inverted ? event.scrollingDeltaY : -event.scrollingDeltaY
        let dx = inverted ? -event.scrollingDeltaX : event.scrollingDeltaX
        scrollAccumulator.width += dx
        scrollAccumulator.height += dy

        if event.phase == .ended || event.phase == .cancelled {
            scrollAccumulator = .zero
            scrollConsumed = false
            return !model.isOpen
        }
        guard !scrollConsumed else { return !model.isOpen }

        if !model.isOpen {
            if LiveActivityCenter.shared.isPresentingNotification {
                // A notification goes away with a swipe up (into the camera) or to a side.
                if scrollAccumulator.height < -12 {
                    scrollConsumed = true
                    NotificationMirror.shared.dismiss(.up)
                    return true
                }
                if abs(scrollAccumulator.width) > 34 {
                    scrollConsumed = true
                    NotificationMirror.shared.dismiss(scrollAccumulator.width > 0 ? .right : .left)
                    return true
                }
            }
            if scrollAccumulator.height > 14 {
                scrollConsumed = true
                open()
            } else if abs(scrollAccumulator.width) > 40, NowPlayingService.shared.hasActiveMedia {
                scrollConsumed = true
                Haptics.tap()
                scrollAccumulator.width > 0 ? NowPlayingService.shared.next() : NowPlayingService.shared.previous()
            }
            return true
        }

        // Swipe up on the header closes the panel.
        let location = NSEvent.mouseLocation
        let headerBottom = model.geometry.topY - model.notchSize.height - 6
        if location.y >= headerBottom, scrollAccumulator.height < -18 {
            scrollConsumed = true
            close()
            return true
        }
        return false
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window === panel else { return false }
        if event.keyCode == 53, !isTerminalFocused { // Escape
            close()
            return true
        }
        if event.keyCode == 49, model.tab == .shelf, !isEditingText, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            QuickLookController.shared.show(ShelfStore.shared.selectedItems.map(\.url))
            return true
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, let characters = event.charactersIgnoringModifiers {
            if characters == "," {
                SettingsWindowController.shared.show()
                return true
            }
            if let number = Int(characters), (0...9).contains(number) {
                // ⌘1…⌘9 are the first nine tabs and ⌘0 the tenth, like browser tabs.
                let tabs = Preferences.shared.visibleTabs
                let index = number == 0 ? 9 : number - 1
                if index < tabs.count {
                    model.select(tabs[index])
                    return true
                }
            }
        }
        if flags.contains(.control), event.keyCode == 48 { // ⌃Tab
            model.selectAdjacentTab(flags.contains(.shift) ? -1 : 1)
            return true
        }
        return false
    }
}

/// Detects a quick left-right "shake" of the pointer while dragging files.
struct ShakeDetector {
    private var samples: [(x: CGFloat, time: TimeInterval)] = []
    private var lastDirection: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var lastTrigger: TimeInterval = 0

    mutating func reset() {
        samples.removeAll()
        reversals.removeAll()
        lastDirection = 0
    }

    /// Returns `true` once when a shake is recognized.
    mutating func register(_ point: CGPoint) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = samples.last {
            let delta = point.x - last.x
            if abs(delta) > 6 {
                let direction: CGFloat = delta > 0 ? 1 : -1
                if lastDirection != 0 && direction != lastDirection {
                    reversals.append(now)
                }
                lastDirection = direction
                samples.append((point.x, now))
            }
        } else {
            samples.append((point.x, now))
        }
        samples.removeAll { now - $0.time > 0.6 }
        reversals.removeAll { now - $0 > 0.6 }
        if reversals.count >= 4, now - lastTrigger > 1.2 {
            lastTrigger = now
            reversals.removeAll()
            return true
        }
        return false
    }
}
