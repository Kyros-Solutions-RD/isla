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

enum IslaMetrics {
    static let cardRadius: CGFloat = 18
    static let innerPadding: CGFloat = 12
    static let contentInset: CGFloat = 14
}

// MARK: - Card

struct IslaCard<Content: View>: View {
    var padding: CGFloat = IslaMetrics.innerPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                    .fill(.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: IslaMetrics.cardRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                    }
            }
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
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(NotchPillButtonStyle())
                    .padding(.top, 2)
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
