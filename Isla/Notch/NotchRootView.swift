//
//  NotchRootView.swift
//  Isla
//
//  The SwiftUI surface drawn inside each notch panel. One silhouette morphs
//  between the closed notch, live activities and the open Nook.
//

import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @Bindable var model: NotchViewModel
    private let prefs = Preferences.shared
    private let activities = LiveActivityCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = model.shapeSize
        let radii = model.cornerRadii
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)
        let motion = IslaMotion.island(to: model.phase, reduceMotion: reduceMotion)
        let notification = activities.presented?.kind.notification
        let arrival = IslaMotion.notification(arriving: notification != nil, reduceMotion: reduceMotion)

        // The island's width and height ride their own springs (see `IslaMotion.island`).
        // Only this empty frame is animated; the surface and the content are laid out
        // inside it on every frame, so they always fill exactly the shape on screen.
        // A notification pours out the same way: wider first, then down.
        Color.clear
            .modifier(IslandHeight(height: size.height))
            .animation(motion.height, value: model.phase)
            .animation(arrival.height, value: notification?.id)
            .modifier(IslandWidth(width: size.width))
            .animation(motion.width, value: model.phase)
            .animation(arrival.width, value: notification?.id)
            .background(alignment: .top) {
                NotchSurface(model: model, shape: shape)
            }
            .overlay(alignment: .top) {
                Group {
                    if model.isOpen {
                        OpenNotchView(model: model)
                            .transition(.nookContent)
                    } else if let activity = activities.presented {
                        ClosedActivityView(activity: activity, model: model)
                            .id(activity.id)
                            .transition(activity.kind.notification == nil ? .islandActivity
                                        : .notificationExit(NotificationMirror.shared.exit))
                            // Tucked into the camera for the menu bar, the ears fade as they go.
                            .opacity(model.isTuckedAway ? 0 : 1)
                            .blur(radius: model.isTuckedAway && !reduceMotion ? 3 : 0)
                            .animation(model.isTuckedAway ? .easeOut(duration: 0.12) : IslaMotion.content.delay(0.08),
                                       value: model.isTuckedAway)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .overlay(alignment: .bottom) {
                PeekHandle(visible: model.phase == .peek)
            }
        .clipShape(shape)
        .contentShape(shape)
        .background(alignment: .bottom) {
            // More notifications wait underneath, like a stack of cards.
            NotificationStackBackdrop(depth: model.isOpen ? 0 : activities.notificationStackDepth,
                                      tint: notification.map { NotificationApps.shared.tint(for: $0.app) })
        }
        .overlay(alignment: .topTrailing) {
            // A second activity splits off into its own small bubble, like the Dynamic Island.
            if let side = model.secondaryBubbleSide, let secondary = activities.secondary {
                SecondaryBubble(activity: secondary, model: model, side: side)
                    .id(secondary.id)
                    .offset(x: NotchViewModel.bubbleGap + side + 10)
                    .transition(.modifier(active: BubbleSplit(progress: 0, distance: side + 16),
                                          identity: BubbleSplit(progress: 1, distance: side + 16)))
            }
        }
        .background(alignment: .top) {
            // Soft shadow lifts the open panel off the desktop without
            // darkening the glass itself. It takes the island's size as it animates.
            shape
                .fill(.black)
                .shadow(color: .black.opacity(model.isOpen && prefs.showShadow ? 0.5 : 0), radius: 26, y: 14)
                .mask {
                    InverseShape(shape: shape, outset: 80)
                        .fill(style: FillStyle(eoFill: true))
                }
                .opacity(model.isOpen ? 1 : 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if model.isDropTargeted && !model.isOpen {
                shape
                    .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5)
            }
        }
        .onDrop(of: ShelfStore.acceptedTypes, isTargeted: $model.isDropTargeted) { providers in
            ShelfStore.shared.add(providers: providers)
            model.controller?.open(.shelf)
            Haptics.tap(.levelChange)
            return true
        }
        .onTapGesture {
            if !model.isOpen { model.controller?.open() }
        }
        .contextMenu { NotchContextMenu(model: model) }
        // A file dragged over the closed notch makes it swell, inviting the drop.
        .scaleEffect(model.isDropTargeted && !model.isOpen ? 1.07 : 1, anchor: .top)
        .animation(IslaMotion.activity, value: model.isDropTargeted)
        .modifier(AttentionNudge(model: model))
        // An ongoing activity with news opens its compact ears for a moment, then settles.
        .onChange(of: activities.presentedHeadline) { _, headline in
            guard !headline.isEmpty, activities.transient == nil else { return }
            activities.showDetailBriefly()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(model.isOpen ? IslaMotion.open : IslaMotion.close, value: model.phase)
        .animation(IslaMotion.activity, value: activities.presented?.id)
        .animation(IslaMotion.activity, value: activities.secondary?.id)
        .animation(IslaMotion.activity, value: model.secondaryBubbleSide)
        .animation(IslaMotion.activity, value: size)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}

/// Under the pointer, a small handle appears at the foot of the island: it can be pulled open.
private struct PeekHandle: View {
    let visible: Bool

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.4))
            .frame(width: visible ? 26 : 8, height: 3)
            .padding(.bottom, 2.5)
            .opacity(visible ? 1 : 0)
            .animation(visible ? IslaMotion.activity.delay(0.06) : .easeOut(duration: 0.12), value: visible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// When something needs you (an agent waiting on an answer, a timer that ended, a low
/// battery), the island gives one small shake once it has grown, like the Dynamic Island.
private struct AttentionNudge: ViewModifier {
    let model: NotchViewModel
    @State private var trigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.32)
                    CubicKeyframe(-7, duration: 0.07)
                    CubicKeyframe(6, duration: 0.09)
                    CubicKeyframe(-4, duration: 0.08)
                    CubicKeyframe(2, duration: 0.08)
                    SpringKeyframe(0, duration: 0.24, spring: .snappy)
                }
            }
            .onChange(of: LiveActivityCenter.shared.presented?.id) { _, _ in
                // Notifications nudge on every arrival instead (below), stacked ones included.
                guard !reduceMotion, !model.isOpen, let kind = LiveActivityCenter.shared.presented?.kind,
                      kind.notification == nil, kind.wantsAttention else { return }
                trigger += 1
            }
            .onChange(of: NotificationMirror.shared.arrivals) { _, _ in
                guard !reduceMotion, !model.isOpen,
                      LiveActivityCenter.shared.presented?.kind.notification?.isMessage == true else { return }
                trigger += 1
            }
    }
}

private extension AnyTransition {
    /// The Nook's content fades in behind the growing island; closing, it folds back
    /// into the camera as it fades.
    static let nookContent = AnyTransition.asymmetric(
        insertion: AnyTransition.opacity.animation(.easeOut(duration: 0.16).delay(0.04)),
        removal: AnyTransition(.blurReplace)
            .combined(with: .scale(scale: 0.94, anchor: .top))
            .combined(with: .opacity)
            .animation(.easeIn(duration: 0.14)))

    /// A live activity arrives on the island's spring and leaves quickly, so its ears never
    /// linger over the Nook opening or over the activity that takes their place.
    /// A notification arrives like any activity, and leaves the way it was swiped: up into
    /// the camera or off to a side.
    static func notificationExit(_ exit: NotificationMirror.Exit) -> AnyTransition {
        let removal: AnyTransition
        switch exit {
        case .up: removal = .offset(y: -18).combined(with: .scale(scale: 0.9, anchor: .top))
        case .left: removal = .offset(x: -60)
        case .right: removal = .offset(x: 60)
        case .fade: removal = .scale(scale: 0.96, anchor: .top)
        }
        return AnyTransition.asymmetric(
            insertion: AnyTransition.opacity.combined(with: AnyTransition(.blurReplace)).animation(IslaMotion.activity),
            removal: removal.combined(with: .opacity).combined(with: AnyTransition(.blurReplace)).animation(.easeIn(duration: 0.16)))
    }

    static let islandActivity = AnyTransition.asymmetric(
        insertion: AnyTransition.opacity.combined(with: AnyTransition(.blurReplace)).animation(IslaMotion.activity),
        removal: AnyTransition.opacity.combined(with: AnyTransition(.blurReplace)).animation(.easeIn(duration: 0.12)))
}

// MARK: - Surface

/// The island's height as an animatable value. SwiftUI hands the body every in-between
/// height, so whatever hangs off this frame is laid out fresh on each frame.
private struct IslandHeight: ViewModifier, Animatable {
    var height: CGFloat
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func body(content: Content) -> some View {
        content.frame(height: max(0, height))
    }
}

/// The island's width; see ``IslandHeight``.
private struct IslandWidth: ViewModifier, Animatable {
    var width: CGFloat
    var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }

    func body(content: Content) -> some View {
        content.frame(width: max(0, width))
    }
}

/// A large rectangle with the notch punched out, used to mask its shadow.
struct InverseShape<S: Shape>: Shape {
    var shape: S
    var outset: CGFloat

    var animatableData: S.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -outset, dy: -outset))
        path.addPath(shape.path(in: rect))
        return path
    }
}

/// Black when closed so it disappears into the camera housing; Liquid Glass
/// (or classic black) once the Nook opens.
struct NotchSurface: View {
    let model: NotchViewModel
    let shape: NotchShape
    private let prefs = Preferences.shared
    private let media = NowPlayingService.shared

    var body: some View {
        let glass = prefs.notchStyle == .liquidGlass
        let open = model.isOpen

        ZStack(alignment: .top) {
            if glass {
                Color.clear
                    .glassEffect(.regular.tint(glassTint), in: shape)
            }
            shape
                .fill(Color.black)
                .opacity(glass && open ? 0 : 1)

            if open && glass && model.geometry.hasHardwareNotch {
                // Keep the camera housing crisp inside the glass.
                NotchShape(topRadius: 6, bottomRadius: 10)
                    .fill(Color.black)
                    .frame(width: model.notchSize.width + 12, height: model.notchSize.height)
            }

            if open && prefs.tintWithArtwork, let accent = media.accentColor, media.hasActiveMedia, model.tab == .home {
                shape
                    .fill(RadialGradient(colors: [accent.opacity(0.22), .clear],
                                         center: .bottomLeading, startRadius: 10, endRadius: 420))
                    .allowsHitTesting(false)
            }

            if open {
                // A hairline of light along the sides and the bottom, brightest at the lower
                // edge, so the panel reads as a lit object on any wallpaper. It fades out
                // toward the top, where the island melts into the screen edge.
                shape
                    .stroke(LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                                   .init(color: .white.opacity(glass ? 0.05 : 0.07), location: 0.45),
                                                   .init(color: .white.opacity(glass ? 0.13 : 0.17), location: 1)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    private var glassTint: Color {
        Color.black.opacity(prefs.glassTint)
    }
}

// MARK: - Context menu

struct NotchContextMenu: View {
    let model: NotchViewModel

    var body: some View {
        Button("Open Nook") { model.controller?.open(.home, makeKey: true) }
        Button("Shelf") { model.controller?.open(.shelf, makeKey: true) }
        Button("Clipboard") { model.controller?.open(.clipboard, makeKey: true) }
        Button("AI Agents") { model.controller?.open(.agents, makeKey: true) }
        Divider()
        Button("Customize Nook…") { SettingsWindowController.shared.show(pane: .nook) }
        Button("Settings…") { SettingsWindowController.shared.show() }
        Divider()
        Button("Quit Isla") { NSApp.terminate(nil) }
    }
}

// MARK: - Open state

struct OpenNotchView: View {
    @Bindable var model: NotchViewModel
    /// Width of the open island's curved top corners (its `NotchShape` top radius).
    static let shoulder: CGFloat = 16
    /// Room between the island's sides and its content.
    static let margin: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            // One edge for the header and the cards: the island's straight sides start
            // `shoulder` points in (its curved top corners), and the content sits a real
            // margin inside them, about as much as it leaves at the bottom.
            NotchHeader(model: model)
                .frame(height: model.notchSize.height)
                .padding(.horizontal, Self.shoulder + Self.margin)
                .zIndex(1)

            TabContent(model: model)
                .padding(.horizontal, Self.shoulder + Self.margin)
                .padding(.top, 8)
                .padding(.bottom, 14)
                // minHeight 0: a tab that asks for more room than the panel has can never
                // push the header up under the camera.
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(width: model.openSize.width, height: model.openSize.height)
        .overlay(alignment: .top) {
            NookNotificationLayer(topInset: model.notchSize.height + 4)
        }
    }
}

/// A notification that arrives while the Nook is open drops out of the camera as a small
/// card over the content, instead of waiting for the Nook to close. Its own view, so brief
/// activities (volume, brightness) never re-render the whole panel.
private struct NookNotificationLayer: View {
    let topInset: CGFloat

    var body: some View {
        let notification = LiveActivityCenter.shared.transient?.kind.notification
        ZStack(alignment: .top) {
            if let notification {
                NookNotificationToast(notification: notification)
                    .padding(.top, topInset)
                    .id(notification.id)
                    .transition(.asymmetric(
                        insertion: .offset(y: -16).combined(with: .scale(scale: 0.86, anchor: .top)).combined(with: .opacity),
                        removal: .offset(y: -10).combined(with: .scale(scale: 0.92, anchor: .top)).combined(with: .opacity)))
            }
        }
        .animation(IslaMotion.activity, value: notification?.id)
    }
}

struct TabContent: View {
    @Bindable var model: NotchViewModel

    var body: some View {
        ZStack {
            switch model.tab {
            case .home: HomeView(model: model)
            case .agents: AgentsView(model: model)
            case .shelf: ShelfView(model: model)
            case .clipboard: ClipboardView(model: model)
            case .calendar: CalendarView(model: model)
            case .tasks: TasksView(model: model)
            case .timers: TimersView(model: model)
            case .notes: NotesView(model: model)
            case .mirror: MirrorView(model: model)
            case .teleprompter: TeleprompterView(model: model)
            case .shortcuts: ShortcutsView(model: model)
            case .terminal: NotchTerminalView(model: model)
            case .launcher: LauncherView(model: model)
            case .chat: LocalChatView(model: model)
            }
        }
        .id(model.tab)
        .transition(.asymmetric(
            insertion: .modifier(active: TabSlide(x: 22 * model.tabDirection, blur: 6, opacity: 0),
                                 identity: TabSlide(x: 0, blur: 0, opacity: 1)),
            removal: .modifier(active: TabSlide(x: 0, blur: 6, opacity: 0),
                               identity: TabSlide(x: 0, blur: 0, opacity: 1)).animation(.easeIn(duration: 0.12))))
    }
}

// MARK: - Header

struct NotchHeader: View {
    @Bindable var model: NotchViewModel
    @Namespace private var selection
    private let prefs = Preferences.shared

    var body: some View {
        let sideWidth = (model.openSize.width - model.notchSize.width) / 2 - 30
        let tabs = prefs.visibleTabs
        let capacity = max(1, Int((sideWidth - 8) / 33))
        let shown = tabs.count > capacity ? Array(tabs.prefix(capacity - 1)) : tabs
        let overflow = tabs.count > capacity ? Array(tabs.dropFirst(capacity - 1)) : []

        HStack(spacing: 0) {
            HStack(spacing: 3) {
                // The icons come out of the camera one after another: the one next to the
                // notch first, the outermost last, following the island as it widens.
                ForEach(Array(shown.enumerated()), id: \.element) { index, tab in
                    tabButton(tab)
                        .emerge(delay: 0.03 + Double(shown.count - 1 - index) * 0.022,
                                offset: CGSize(width: 10, height: -4))
                }
                if !overflow.isEmpty {
                    Menu {
                        ForEach(overflow) { tab in
                            Button { model.select(tab) } label: { Label(tab.title, systemImage: tab.symbol) }
                        }
                    } label: {
                        Image(systemName: overflow.contains(model.tab) ? model.tab.symbol : "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 30, height: 24)
                            .foregroundStyle(overflow.contains(model.tab) ? .white : .white.opacity(0.55))
                            .background {
                                if overflow.contains(model.tab) {
                                    Capsule().fill(.white.opacity(0.16))
                                }
                            }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel(Text("More Tabs"))
                    .emerge(delay: 0.03 + Double(shown.count) * 0.022, offset: CGSize(width: 10, height: -4))
                }
            }
            .frame(width: sideWidth, alignment: .leading)

            Spacer(minLength: model.notchSize.width)

            HeaderActions(model: model)
                .emerge(delay: 0.05, offset: CGSize(width: -10, height: -4))
                .frame(width: sideWidth, alignment: .trailing)
        }
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        HeaderTabButton(tab: tab, selected: model.tab == tab, selection: selection) {
            model.select(tab)
            Haptics.tap()
        }
        .overlay(alignment: .topTrailing) {
            if tab == .shelf, ShelfStore.shared.items.count > 0 {
                Text("\(ShelfStore.shared.items.count)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(ShelfStore.shared.items.count)))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3.5)
                    .frame(minWidth: 13, minHeight: 13)
                    .background(Capsule().fill(.white))
                    .offset(x: 2, y: -2)
            } else if tab == .agents, let state = AgentMonitor.shared.activeSessions.first?.state {
                // A live dot while an agent works (green) or waits on an answer (orange).
                Circle()
                    .fill(state.tint)
                    .frame(width: 6, height: 6)
                    .background(Circle().stroke(.black.opacity(0.6), lineWidth: 1.5))
                    .offset(x: -3, y: 2)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(IslaMotion.snappy, value: AgentMonitor.shared.activeSessions.first?.state)
        .animation(IslaMotion.snappy, value: ShelfStore.shared.items.count)
    }
}

/// A tab icon in the Nook header: a hover plate, a press squeeze and the shared
/// selection capsule that glides between tabs.
private struct HeaderTabButton: View {
    let tab: NotchTab
    let selected: Bool
    let selection: Namespace.ID
    let action: () -> Void
    @State private var hovering = false
    /// Bumped each time this tab becomes the selected one, for a single bounce.
    @State private var bounce = 0
    /// The tab's name, shown under the icon after a short hover (quicker than a tooltip).
    @State private var showsName = false
    @State private var nameDelay: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: bounce)
                .frame(width: 30, height: 24)
                .foregroundStyle(selected ? Color.white : Color.white.opacity(hovering ? 0.85 : 0.5))
                .background {
                    if selected {
                        Capsule()
                            .fill(.white.opacity(0.17))
                            .matchedGeometryEffect(id: "selected-tab", in: selection)
                    } else if hovering {
                        Capsule().fill(.white.opacity(0.08))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressSqueeze())
        .onHover { inside in
            hovering = inside
            nameDelay?.cancel()
            if inside {
                nameDelay = Task {
                    try? await Task.sleep(for: .milliseconds(380))
                    if !Task.isCancelled { showsName = true }
                }
            } else {
                showsName = false
            }
        }
        .overlay(alignment: .bottom) {
            if showsName {
                Text(tab.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(white: 0.1)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                    .offset(y: 26)
                    .transition(.offset(y: -5).combined(with: .opacity).combined(with: .scale(scale: 0.88, anchor: .top)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(IslaMotion.snappy, value: showsName)
        .onChange(of: selected) { _, isSelected in
            if isSelected { bounce += 1 }
        }
        .animation(IslaMotion.snappy, value: hovering)
        // VoiceOver says the tab's name, not the symbol's ("Grid 2x2", "Sparkle"…).
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Shrinks a control slightly while it is pressed.
struct PressSqueeze: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(IslaMotion.snappy, value: configuration.isPressed)
    }
}

struct HeaderActions: View {
    @Bindable var model: NotchViewModel
    private let battery = BatteryMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            if UpdateManager.shared.availableVersion != nil {
                Button { UpdateManager.shared.checkForUpdates() } label: {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
                }
                .buttonStyle(NotchIconButtonStyle(size: 26))
                .help(String(localized: "Update available"))
                .accessibilityLabel(Text("Update available"))
            }
            if QuickActions.shared.keepAwake {
                Button { QuickActions.shared.stopKeepAwake() } label: {
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange)
                }
                .buttonStyle(NotchIconButtonStyle(size: 26))
                .help(String(localized: "Keeping your Mac awake. Click to stop."))
                .accessibilityLabel(Text("Keeping your Mac awake. Click to stop."))
                .transition(.scale.combined(with: .opacity))
            }
            if battery.hasBattery {
                HStack(spacing: 4) {
                    Text("\(battery.level)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(battery.level)))
                        .animation(IslaMotion.snappy, value: battery.level)
                        .foregroundStyle(.white.opacity(0.75))
                    BatteryGlyph(level: battery.level, charging: battery.isCharging || battery.isPluggedIn, width: 22)
                }
                .padding(.trailing, 6)
                .help(battery.statusDescription)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(battery.level)% · \(battery.statusDescription)"))
            }

            Button {
                if model.tab == .launcher {
                    model.select(Preferences.shared.visibleTabs.first ?? .home)
                } else {
                    model.controller?.open(.launcher, makeKey: true)
                }
                Haptics.tap()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(model.tab == .launcher ? Color.accentColor : .white)
            }
            .buttonStyle(NotchIconButtonStyle(size: 26))
            .help(String(localized: "Search"))
            .accessibilityLabel(Text("Search"))

            Button {
                model.isPinned.toggle()
                Haptics.tap()
            } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .rotationEffect(.degrees(model.isPinned ? 0 : 35))
            }
            .buttonStyle(NotchIconButtonStyle(size: 26))
            .help(model.isPinned ? String(localized: "Unpin") : String(localized: "Keep open"))
            .accessibilityLabel(model.isPinned ? Text("Unpin") : Text("Keep open"))

            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(NotchIconButtonStyle(size: 26))
            .help(String(localized: "Settings"))
            .accessibilityLabel(Text("Settings"))
        }
    }
}
