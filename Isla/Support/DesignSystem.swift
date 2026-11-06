//
//  DesignSystem.swift
//  Isla
//
//  Shared motion curves, surfaces and controls so every part of the notch
//  feels like one system.
//

import SwiftUI

enum IslaMotion {
    /// Opening has a touch of bounce, like the Dynamic Island; closing is quick and settles flat.
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.76)
    static let close = Animation.spring(response: 0.32, dampingFraction: 0.94)
    static let activity = Animation.spring(response: 0.4, dampingFraction: 0.76)
    static let snappy = Animation.snappy(duration: 0.26)
    static let content = Animation.smooth(duration: 0.3)
    /// Content rising out of the camera housing once the shape has room for it.
    static let emerge = Animation.spring(response: 0.5, dampingFraction: 0.82)

    /// The island's width and height move on their own springs, so it pours out of the
    /// camera instead of zooming: opening, it widens first and then drops down with a little
    /// bounce; closing, it folds up first and then draws in toward the camera.
    /// Peeking under the pointer keeps the livelier activity spring on both axes.
    static func island(to phase: NotchViewModel.Phase, reduceMotion: Bool) -> (width: Animation, height: Animation) {
        if reduceMotion {
            let plain = Animation.smooth(duration: 0.24)
            return (plain, plain)
        }
        switch phase {
        case .open: return (.spring(response: 0.36, dampingFraction: 0.8), .spring(response: 0.47, dampingFraction: 0.72))
        case .peek: return (activity, activity)
        case .closed: return (.spring(response: 0.36, dampingFraction: 0.9), .spring(response: 0.25, dampingFraction: 1))
        }
    }
}

// MARK: - Emerging from the notch

/// Content that comes out of the notch: blurred, a little smaller and tucked toward the
/// camera, then it settles. Each Nook card uses a growing delay so they arrive in order.
struct EmergeModifier: ViewModifier {
    var delay: Double = 0
    var offset: CGSize = CGSize(width: 0, height: -8)
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let settled = shown || reduceMotion
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: settled ? 0 : 7)
            .scaleEffect(settled ? 1 : 0.95, anchor: .top)
            .offset(settled ? .zero : offset)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : IslaMotion.emerge.delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// See ``EmergeModifier``.
    func emerge(delay: Double = 0, offset: CGSize = CGSize(width: 0, height: -8)) -> some View {
        modifier(EmergeModifier(delay: delay, offset: offset))
    }
}

/// A tab's content sliding in from the side of the tab that was chosen.
struct TabSlide: ViewModifier {
    var x: CGFloat
    var blur: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).blur(radius: blur).opacity(opacity)
    }
}

/// Fades a scrolling list into its card at the top and bottom edges, so rows slide out of
/// view softly instead of being cut. Mostly at the bottom, where the list continues.
struct ScrollFade: ViewModifier {
    var top: CGFloat = 5
    var bottom: CGFloat = 16

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.15), .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: top)
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: bottom)
            }
        }
    }
}

extension View {
    /// See ``ScrollFade``.
    func scrollFade(top: CGFloat = 5, bottom: CGFloat = 16) -> some View {
        modifier(ScrollFade(top: top, bottom: bottom))
    }
}

enum IslaMetrics {
    static let cardRadius: CGFloat = 18
    static let innerPadding: CGFloat = 12
    static let contentInset: CGFloat = 14
}

// MARK: - Card

struct IslaCard<Content: View>: View {
    var padding: CGFloat = IslaMetrics.innerPadding
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        let card = RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // Lit from above: a touch brighter at the top, with a rim that catches the
                // light along the upper edge. Under the pointer the card glows a little.
                card
                    .fill(LinearGradient(colors: [.white.opacity(hovering ? 0.1 : 0.085),
                                                  .white.opacity(hovering ? 0.075 : 0.06)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay {
                        card.strokeBorder(LinearGradient(colors: [.white.opacity(hovering ? 0.16 : 0.12),
                                                                  .white.opacity(0.04)],
                                                         startPoint: .top, endPoint: .bottom),
                                          lineWidth: 0.6)
                    }
                    .animation(.easeOut(duration: 0.18), value: hovering)
            }
            .onHover { hovering = $0 }
    }
}

struct CardHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    var tint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
                .lineLimit(1)
            Spacer(minLength: 4)
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, symbol: String, tint: Color = .secondary) {
        self.init(title: title, symbol: symbol, tint: tint) { EmptyView() }
    }
}

// MARK: - Buttons

/// Circular icon button with a soft hover plate, used across the notch.
struct NotchIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        NotchIconButtonBody(configuration: configuration, size: size, prominent: prominent)
    }

    private struct NotchIconButtonBody: View {
        let configuration: Configuration
        let size: CGFloat
        let prominent: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(prominent ? Color.black : Color.white)
                .frame(width: size, height: size)
                .background {
                    Circle().fill(prominent ? Color.white : Color.white.opacity(hovering ? 0.14 : 0.0))
                }
                .scaleEffect(configuration.isPressed ? 0.88 : 1)
                .animation(IslaMotion.snappy, value: configuration.isPressed)
                .animation(IslaMotion.snappy, value: hovering)
                .onHover { hovering = $0 }
                .contentShape(Circle())
        }
    }
}

/// Capsule button for secondary actions inside the notch.
struct NotchPillButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, tint: tint)
    }

    private struct PillBody: View {
        let configuration: Configuration
        let tint: Color
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(tint == .white ? Color.white : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill((tint == .white ? Color.white : tint).opacity(hovering ? 0.22 : 0.13))
                }
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(IslaMotion.snappy, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// Row with a hover highlight, used for lists inside the notch.
struct HoverRow<Content: View>: View {
    var radius: CGFloat = 10
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.08 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { hovering = $0 }
            .animation(IslaMotion.snappy, value: hovering)
    }
}

// MARK: - Empty states

struct NotchEmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        // Each line comes out of the notch a beat after the one above, like the Nook's cards.
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
                .emerge(delay: 0.08)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .emerge(delay: 0.12, offset: CGSize(width: 0, height: -5))
            if let message {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .emerge(delay: 0.16, offset: CGSize(width: 0, height: -5))
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(NotchPillButtonStyle())
                    .padding(.top, 2)
                    .emerge(delay: 0.2, offset: CGSize(width: 0, height: -5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Marquee

/// Scrolls text horizontally when it does not fit, like the system media UI.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .semibold)
    var speed: Double = 28

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let overflow = textWidth - proxy.size.width
            TimelineView(.animation(minimumInterval: 1 / 30, paused: overflow <= 0)) { timeline in
                let gap: CGFloat = 36
                let cycle = Double(textWidth + gap) / speed
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = overflow > 0 ? max(0, (t.truncatingRemainder(dividingBy: cycle + 2)) - 2) : 0
                let offset = overflow > 0 ? -CGFloat(phase / cycle) * (textWidth + gap) : 0
                HStack(spacing: gap) {
                    label
                    if overflow > 0 { label }
                }
                .offset(x: offset)
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipped()
            .mask {
                LinearGradient(stops: overflow > 0 ? [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                    .init(color: .black, location: 0.92), .init(color: .clear, location: 1)
                ] : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
                startPoint: .leading, endPoint: .trailing)
            }
        }
        .frame(height: lineHeight)
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { textWidth = proxy.size.width }
                        .onChange(of: text) { textWidth = proxy.size.width }
                }
            }
    }

    private var lineHeight: CGFloat { 18 }
}
