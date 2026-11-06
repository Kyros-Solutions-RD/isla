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

    var body: some View {
        let size = model.shapeSize
        let radii = model.cornerRadii
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        ZStack(alignment: .top) {
            NotchSurface(model: model, shape: shape)

            Group {
                if model.isOpen {
                    OpenNotchView(model: model)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.16).delay(0.04)),
                            removal: AnyTransition(.blurReplace).combined(with: .opacity).animation(.easeIn(duration: 0.13))))
                } else if let activity = activities.presented {
                    ClosedActivityView(activity: activity, model: model)
                        .id(activity.id)
                        .transition(.opacity.combined(with: .blurReplace).animation(IslaMotion.activity))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .contentShape(shape)
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
            // darkening the glass itself.
            shape
                .fill(.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.isOpen && prefs.showShadow ? 0.5 : 0), radius: 26, y: 14)
                .mask {
                    InverseShape(shape: shape, outset: 80)
                        .fill(style: FillStyle(eoFill: true))
                        .frame(width: size.width, height: size.height)
                }
                .opacity(model.isOpen ? 1 : 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if model.isDropTargeted && !model.isOpen {
                shape
                    .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5)
                    .frame(width: size.width, height: size.height)
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

// MARK: - Surface

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

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(model: model)
                .frame(height: model.notchSize.height)
                .padding(.horizontal, 22)

            TabContent(model: model)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
                // minHeight 0: a tab that asks for more room than the panel has can never
                // push the header up under the camera.
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(width: model.openSize.width, height: model.openSize.height)
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
                ForEach(shown) { tab in
                    tabButton(tab)
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
                }
            }
            .frame(width: sideWidth, alignment: .leading)

            Spacer(minLength: model.notchSize.width)

            HeaderActions(model: model)
                .frame(width: sideWidth, alignment: .trailing)
        }
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        HeaderTabButton(tab: tab, selected: model.tab == tab, selection: selection) {
            model.select(tab)
            Haptics.tap()
        }
        .help(tab.titleString)
        .overlay(alignment: .topTrailing) {
            if tab == .shelf, ShelfStore.shared.items.count > 0 {
                Text("\(ShelfStore.shared.items.count)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
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

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
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
        .onHover { hovering = $0 }
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
                        .foregroundStyle(.white.opacity(0.75))
                    BatteryGlyph(level: battery.level, charging: battery.isCharging || battery.isPluggedIn, width: 22)
                }
                .padding(.trailing, 6)
                .help(battery.statusDescription)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(battery.level)% · \(battery.statusDescription)"))
            }

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
