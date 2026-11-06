//
//  NotificationViews.swift
//  Isla
//
//  A notification on the island: the app's real icon and the sender in the ears, the message
//  underneath. It pours out of the camera, stacks when more arrive, follows a drag, opens with
//  a click and leaves with a swipe. Plus the Nook widget with the recent ones.
//

import AppKit
import SwiftUI

struct NotificationIslandContent: View {
    let notification: IslaNotification
    let model: NotchViewModel

    var body: some View {
        // The card in front changes as notifications arrive: the new one comes out of the
        // camera and the previous one sinks into the stack underneath.
        ZStack(alignment: .top) {
            NotificationIslandCard(notification: notification, model: model)
                .id(notification.id)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.18)),
                    removal: AnyTransition.offset(y: 9)
                        .combined(with: .scale(scale: 0.93, anchor: .bottom))
                        .combined(with: .opacity)
                        .animation(.easeIn(duration: 0.2))))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(IslaMotion.activity, value: notification.id)
    }
}

private struct NotificationIslandCard: View {
    let notification: IslaNotification
    let model: NotchViewModel
    @State private var drag: CGSize = .zero
    @State private var iconScale: CGFloat = 0.45
    @State private var ripple = false
    /// A bloom of the app's color behind the icon: bright as it lands, then a faint glow.
    @State private var glow: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let notch = model.notchSize
        let layout = model.notificationLayout
            ?? .init(earWidth: NotificationLayout.earWidth(for: notification, revealed: true), detailHeight: 0, revealed: true, expanded: false)
        let earContent = layout.earWidth - NotificationLayout.earInset

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftEar(layout)
                    .frame(width: earContent, alignment: .leading)
                    .padding(.leading, NotificationLayout.earInset)
                    .emerge(delay: 0.06, offset: CGSize(width: 18, height: 0))
                Color.clear.frame(width: notch.width)
                rightEar
                    .frame(width: earContent, alignment: .trailing)
                    .padding(.trailing, NotificationLayout.earInset)
                    .emerge(delay: 0.08, offset: CGSize(width: -18, height: 0))
            }
            .frame(height: notch.height)

            if layout.detailHeight > 0 {
                detail(layout, islandWidth: notch.width + layout.earWidth * 2)
                    .frame(height: layout.detailHeight, alignment: .top)
                    .emerge(delay: 0.17, offset: CGSize(width: 0, height: -7))
                    .transition(.opacity.combined(with: .offset(y: -5)))
            }
        }
        .foregroundStyle(.white)
        .background(alignment: .topLeading) {
            RadialGradient(colors: [NotificationApps.shared.tint(for: notification.app).opacity(0.3), .clear],
                           center: UnitPoint(x: 0.04, y: 0.1), startRadius: 2, endRadius: 170)
                .opacity(glow)
                .allowsHitTesting(false)
        }
        .offset(drag)
        .contentShape(Rectangle())
        .gesture(swipe)
        .onAppear {
            guard !reduceMotion else { glow = 0.4; return }
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) { glow = 1 }
            withAnimation(.easeInOut(duration: 1.1).delay(0.5)) { glow = 0.4 }
        }
        .onTapGesture { NotificationMirror.shared.open(notification) }
        .animation(IslaMotion.activity, value: layout)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(revealed: layout.revealed))
        .accessibilityAction { NotificationMirror.shared.open(notification) }
        .accessibilityAction(named: Text("Dismiss")) { NotificationMirror.shared.dismiss(.up) }
    }

    // MARK: Ears

    private func leftEar(_ layout: NotchViewModel.NotificationIslandLayout) -> some View {
        HStack(spacing: NotificationLayout.iconGap) {
            NotificationAppIcon(app: notification.app, fromiPhone: notification.fromiPhone, size: NotificationLayout.iconSize)
                .background {
                    // One ring of the app's color spreads from the icon as it lands.
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(NotificationApps.shared.tint(for: notification.app), lineWidth: 1.5)
                        .scaleEffect(ripple ? 1.75 : 1)
                        .opacity(ripple ? 0 : 0.8)
                }
                .scaleEffect(iconScale)
                .onAppear {
                    guard !reduceMotion else { iconScale = 1; ripple = true; return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.52).delay(0.05)) { iconScale = 1 }
                    withAnimation(.easeOut(duration: 0.75).delay(0.16)) { ripple = true }
                }
            Text(verbatim: NotificationLayout.earLabel(for: notification, revealed: layout.revealed))
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
    }

    private var rightEar: some View {
        HStack(spacing: 5) {
            if notification.count > 1 {
                // Messages folded into this conversation.
                Text("\(notification.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(notification.count)))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 18, minHeight: 17)
                    .background(Capsule().fill(NotificationApps.shared.tint(for: notification.app)))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text("Now")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: Message

    private func detail(_ layout: NotchViewModel.NotificationIslandLayout, islandWidth: CGFloat) -> some View {
        let width = islandWidth - NotificationLayout.detailLeading - 18
        let lines = NotificationLayout.bodyLines(for: notification, width: width, expanded: layout.expanded)
        return VStack(alignment: .leading, spacing: 0) {
            if !notification.subtitle.isEmpty {
                Text(verbatim: notification.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .frame(height: NotificationLayout.subtitleHeight, alignment: .leading)
            }
            if lines > 0 {
                Text(verbatim: notification.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(lines)
                    .lineSpacing(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: max(0, width), alignment: .leading)
        .padding(.leading, NotificationLayout.detailLeading)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Swipe

    /// Drag the message up into the camera or off to a side to dismiss it; let go before that
    /// and it springs back.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let t = value.translation
                drag = CGSize(width: t.width * 0.7, height: t.height < 0 ? t.height * 0.6 : t.height * 0.12)
            }
            .onEnded { value in
                let t = value.translation
                let predicted = value.predictedEndTranslation
                if t.height < -14 || predicted.height < -50 {
                    NotificationMirror.shared.dismiss(.up)
                } else if abs(t.width) > 44 || abs(predicted.width) > 120 {
                    NotificationMirror.shared.dismiss((t.width + predicted.width) > 0 ? .right : .left)
                } else {
                    withAnimation(IslaMotion.snappy) { drag = .zero }
                }
            }
    }

    private func accessibilityLabel(revealed: Bool) -> Text {
        guard revealed else { return Text("\(notification.app.name): new notification") }
        let parts = [notification.app.name, notification.sender, notification.subtitle, notification.body].filter { !$0.isEmpty }
        return Text(verbatim: parts.joined(separator: ", "))
    }
}

// MARK: - In the open Nook

/// The notification as a compact card under the camera while the Nook is open.
struct NookNotificationToast: View {
    let notification: IslaNotification
    @State private var hovering = false
    @State private var drag: CGFloat = 0

    var body: some View {
        let revealed = !Preferences.shared.notificationsHideContent || hovering
        HStack(spacing: 9) {
            NotificationAppIcon(app: notification.app, fromiPhone: notification.fromiPhone, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(verbatim: revealed ? notification.sender : notification.app.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    if notification.count > 1 {
                        Text("\(notification.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .background(Capsule().fill(NotificationApps.shared.tint(for: notification.app)))
                    }
                }
                Text(verbatim: revealed ? [notification.subtitle, notification.body].filter { !$0.isEmpty }.joined(separator: " · ")
                                        : String(localized: "Hidden"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(.leading, 9)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color(white: 0.09).opacity(0.97))
                .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.05)],
                                                               startPoint: .top, endPoint: .bottom), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        }
        .scaleEffect(hovering ? 1.03 : 1)
        .offset(y: min(0, drag))
        .foregroundStyle(.white)
        .contentShape(Capsule())
        .onHover { inside in
            hovering = inside
            NotificationMirror.shared.setHovering(inside)
        }
        .onTapGesture { NotificationMirror.shared.open(notification) }
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { drag = $0.translation.height * 0.6 }
            .onEnded { value in
                if value.translation.height < -10 || value.predictedEndTranslation.height < -40 {
                    NotificationMirror.shared.dismiss(.up)
                } else {
                    withAnimation(IslaMotion.snappy) { drag = 0 }
                }
            })
        .animation(IslaMotion.snappy, value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(verbatim: [notification.app.name, notification.sender, notification.body].filter { !$0.isEmpty }.joined(separator: ", ")))
        .accessibilityAction { NotificationMirror.shared.open(notification) }
        .accessibilityAction(named: Text("Dismiss")) { NotificationMirror.shared.dismiss(.up) }
    }
}

// MARK: - Stack

/// Cards peeking out under the island while more notifications wait: one per notification,
/// up to two, each a little narrower and darker than the one above.
struct NotificationStackBackdrop: View {
    let depth: Int
    var tint: Color?

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach([2, 1], id: \.self) { level in
                let shown = level <= depth
                UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                    .fill(Color(white: level == 1 ? 0.17 : 0.115))
                    .overlay {
                        UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.clear, (tint ?? .white).opacity(level == 1 ? 0.28 : 0.18)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 0.6)
                    }
                    .frame(height: 26)
                    .padding(.horizontal, CGFloat(level) * 14)
                    .offset(y: shown ? CGFloat(level) * 5.5 : -6)
                    .scaleEffect(x: shown ? 1 : 0.86, y: 1, anchor: .bottom)
                    .opacity(shown ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.38, dampingFraction: 0.62), value: depth)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension LiveActivityCenter {
    /// How many notifications wait under the one in front (0–2).
    var notificationStackDepth: Int {
        if case .notification(_, let stack)? = presented?.kind { return stack }
        return 0
    }
}

// MARK: - Nook widget

struct NotificationsWidgetCard: View {
    let model: NotchViewModel
    private let mirror = NotificationMirror.shared
    private let prefs = Preferences.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(title: "Notifications", symbol: "bell.badge.fill", tint: .red) {
                    if mirror.status == .needsAccess && !mirror.history.isEmpty {
                        // Reading has stopped (Accessibility was turned off): say so quietly.
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .help(String(localized: "Needs Accessibility"))
                    }
                }
                content
            }
        }
        .contextMenu {
            Button("Clear History") { withAnimation(IslaMotion.content) { mirror.clearHistory() } }
                .disabled(mirror.history.isEmpty)
        }
        .animation(IslaMotion.content, value: mirror.history.map(\.id))
    }

    @ViewBuilder private var content: some View {
        if mirror.status == .off {
            placeholder(symbol: "bell.slash", title: "Notifications are off") {
                Button("Turn On") {
                    prefs.notificationsEnabled = true
                    mirror.refresh()
                }
                .buttonStyle(NotchPillButtonStyle())
            }
        } else if !mirror.history.isEmpty && prefs.notificationsHistory {
            // Ages ("Now", "7 min", "2 h") refresh twice a minute while the Nook is open.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 2) {
                    ForEach(mirror.history.prefix(3)) { item in
                        NotificationWidgetRow(notification: item, now: context.date)
                            .transition(AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96, anchor: .top)))
                    }
                }
            }
            Spacer(minLength: 0)
            if mirror.history.count > 3 {
                Text("+\(mirror.history.count - 3)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        } else if mirror.status == .needsAccess {
            placeholder(symbol: "accessibility", title: "Needs Accessibility") {
                Button("Allow…") { PermissionCenter.shared.request(.accessibility) }
                    .buttonStyle(NotchPillButtonStyle())
            }
        } else {
            placeholder(symbol: "bell", title: prefs.notificationsHistory ? "No notifications yet" : "History is off") { EmptyView() }
        }
    }

    private func placeholder<Action: View>(symbol: String, title: LocalizedStringKey, @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            action()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .transition(.blurReplace)
    }
}

private struct NotificationWidgetRow: View {
    let notification: IslaNotification
    let now: Date
    @State private var hovering = false

    private var age: Text {
        let minutes = Int(now.timeIntervalSince(notification.date) / 60)
        if minutes < 1 { return Text("Now") }
        if minutes < 60 { return Text("\(minutes) min") }
        return Text("\(minutes / 60) h")
    }

    var body: some View {
        let revealed = !Preferences.shared.notificationsHideContent || hovering
        HStack(alignment: .top, spacing: 8) {
            NotificationAppIcon(app: notification.app, fromiPhone: notification.fromiPhone, size: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(verbatim: revealed ? notification.sender : notification.app.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    age
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
                Group {
                    if revealed {
                        Text(verbatim: [notification.subtitle, notification.body].filter { !$0.isEmpty }.joined(separator: " · "))
                    } else {
                        Text("Hidden")
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(hovering ? 0.08 : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture { NotificationMirror.shared.open(notification) }
        .animation(IslaMotion.snappy, value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(verbatim: [notification.app.name, notification.sender, notification.body].joined(separator: ", ")))
        .accessibilityAction { NotificationMirror.shared.open(notification) }
    }
}
