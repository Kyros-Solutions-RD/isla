//
//  NotchViewModel.swift
//  Isla
//
//  Per-display state of the notch: closed, peeking under the pointer, or open
//  with one of the Nook tabs.
//

import SwiftUI

@Observable
@MainActor
final class NotchViewModel {
    enum Phase: Equatable {
        case closed
        case peek
        case open
    }

    let displayID: CGDirectDisplayID
    var geometry: NotchGeometry
    var phase: Phase = .closed
    var tab: NotchTab
    var isPinned = false
    var isHovering = false
    var isDropTargeted = false
    var isDraggingFiles = false
    /// +1 when the newly chosen tab sits to the right of the previous one, -1 to the left.
    var tabDirection: CGFloat = 1
    /// Reasons that temporarily prevent auto-closing (open menus, editing…).
    var holds: Set<String> = []
    @ObservationIgnored weak var controller: NotchWindowController?

    init(displayID: CGDirectDisplayID, geometry: NotchGeometry) {
        self.displayID = displayID
        self.geometry = geometry
        let prefs = Preferences.shared
        self.tab = prefs.rememberLastTab ? prefs.lastTab : .home
        if !prefs.visibleTabs.contains(tab) { tab = prefs.visibleTabs.first ?? .home }
    }

    var isOpen: Bool { phase == .open }

    var notchSize: CGSize { geometry.notchSize }

    var openSize: CGSize {
        let base = Preferences.shared.panelSize.size
        // Make sure the panel always clears the camera housing comfortably.
        return CGSize(width: max(base.width, notchSize.width + 420), height: base.height + max(0, notchSize.height - 32))
    }

    /// Size of the closed notch, including any live activity ears.
    var closedSize: CGSize {
        guard let activity = LiveActivityCenter.shared.presented?.kind else { return notchSize }
        let ears = activity.earWidths(notchHeight: notchSize.height)
        let earWidth = max(ears.left, ears.right)
        return CGSize(width: notchSize.width + earWidth * 2 + (showsIslandLyrics ? 120 : 0),
                      height: notchSize.height + activity.detailHeight + (showsIslandLyrics ? 26 : 0))
    }

    /// Space between the island and the bubble of a second activity.
    static let bubbleGap: CGFloat = 6

    /// Height of the bubble beside the closed island when a second activity is going on.
    var secondaryBubbleSide: CGFloat? {
        guard phase == .closed, LiveActivityCenter.shared.secondary != nil else { return nil }
        return max(26, notchSize.height - 2)
    }

    /// Where the bubble sits on screen, so it can take clicks.
    var secondaryBubbleRect: CGRect? {
        guard let side = secondaryBubbleSide else { return nil }
        let island = geometry.rect(for: shapeSize)
        return CGRect(x: island.maxX + Self.bubbleGap, y: geometry.topY - side, width: side + 10, height: side)
    }

    /// Synced lyrics under the island while music plays (opt-in).
    var showsIslandLyrics: Bool {
        LiveActivityCenter.shared.presented?.kind == .nowPlaying &&
            Preferences.shared.lyricsOnIsland && LyricsService.shared.hasSyncedLyrics
    }

    var shapeSize: CGSize {
        switch phase {
        case .open:
            return openSize
        case .peek:
            let closed = closedSize
            return CGSize(width: closed.width + 18, height: closed.height + 5)
        case .closed:
            return closedSize
        }
    }

    var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch phase {
        case .open:
            return (16, 34)
        case .peek, .closed:
            let hasDetail = (LiveActivityCenter.shared.presented?.kind.detailHeight ?? 0) > 0 || showsIslandLyrics
            let base: CGFloat = geometry.hasHardwareNotch ? 10 : 12
            return (6, hasDetail ? 20 : (phase == .peek ? base + 3 : base))
        }
    }

    // MARK: Actions

    func open(_ tab: NotchTab? = nil) {
        if let tab {
            select(tab)
        }
        guard phase != .open else { return }
        Haptics.tap(.levelChange)
        withAnimation(IslaMotion.open) { phase = .open }
    }

    func close() {
        guard phase != .closed else { return }
        isPinned = false
        holds.removeAll()
        withAnimation(IslaMotion.close) { phase = .closed }
    }

    func toggle(_ tab: NotchTab? = nil) {
        if isOpen && (tab == nil || tab == self.tab) {
            close()
        } else {
            open(tab)
        }
    }

    func peek() {
        guard phase == .closed else { return }
        Haptics.tap(.alignment)
        withAnimation(IslaMotion.activity) { phase = .peek }
    }

    func unpeek() {
        guard phase == .peek else { return }
        withAnimation(IslaMotion.close) { phase = .closed }
    }

    func select(_ tab: NotchTab) {
        guard self.tab != tab else { return }
        let order = Preferences.shared.visibleTabs
        if let from = order.firstIndex(of: self.tab), let to = order.firstIndex(of: tab) {
            tabDirection = to > from ? 1 : -1
        }
        withAnimation(IslaMotion.emerge) { self.tab = tab }
        Preferences.shared.lastTab = tab
    }

    func selectAdjacentTab(_ offset: Int) {
        let tabs = Preferences.shared.visibleTabs
        guard let index = tabs.firstIndex(of: tab) else { return }
        let next = (index + offset + tabs.count) % tabs.count
        select(tabs[next])
        Haptics.tap()
    }
}
