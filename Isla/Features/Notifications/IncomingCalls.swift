//
//  IncomingCalls.swift
//  Isla
//
//  An incoming FaceTime call, or one from the iPhone, rings on the island with large Accept
//  and Decline buttons. They press the same buttons of the system's call alert through
//  Accessibility (the permission Isla already has for notifications), so the call is
//  answered exactly as if you had clicked the alert. When the alert goes (answered
//  elsewhere, missed, declined) the island lets the call go too.
//

import AppKit
import QuartzCore
import SwiftUI

struct IncomingCall: Identifiable, Equatable, Hashable, Sendable {
    var id: String
    /// The system's call alert, to press its buttons.
    var bannerID: String?
    var caller: String
    /// "FaceTime Video", "iPhone"… as the alert says it.
    var detail: String
    var isVideo: Bool
    var app: NotificationAppInfo
}

@Observable
@MainActor
final class CallCenter {
    static let shared = CallCenter()

    private(set) var current: IncomingCall?
    @ObservationIgnored private var sequence = 0

    static let acceptWords = ["Accept", "Aceptar", "Answer", "Contestar", "Responder", "Atender", "Annehmen", "Accepter", "Rispondi", "Atender"]
    static let declineWords = ["Decline", "Rechazar", "Ignore", "Ignorar", "Colgar", "Ablehnen", "Refuser", "Rifiuta"]

    /// A call alert: FaceTime's, with an Accept button.
    static func isCall(_ banner: NotificationBanner, app: NotificationAppInfo) -> Bool {
        let isFaceTime = app.bundleID == "com.apple.FaceTime" || app.name == "FaceTime"
        guard isFaceTime, !banner.buttons.isEmpty else { return false }
        return banner.buttons.contains { label in acceptWords.contains { label.localizedCaseInsensitiveContains($0) } }
    }

    func ring(from banner: NotificationBanner, app: NotificationAppInfo) {
        guard Preferences.shared.callsOnIsland else { return }
        if current?.bannerID == banner.id { return }
        let text = [banner.subtitle, banner.body].joined(separator: " ")
        let video = text.localizedCaseInsensitiveContains("video") || text.localizedCaseInsensitiveContains("vídeo")
        let detail = [banner.subtitle, banner.body].first { !$0.isEmpty } ?? app.name
        sequence &+= 1
        ring(IncomingCall(id: "call-\(sequence)", bannerID: banner.id, caller: banner.title.isEmpty ? app.name : banner.title,
                          detail: banner.fromiPhone ? "iPhone · \(detail)" : detail, isVideo: video, app: app))
    }

    func ring(_ call: IncomingCall) {
        current = call
        // A call stays until it is answered, declined or gone (a minute at most).
        LiveActivityCenter.shared.post(.call(call), duration: 60)
    }

    func accept() { answer(with: Self.acceptWords) }
    func decline() { answer(with: Self.declineWords) }

    private func answer(with words: [String]) {
        guard let call = current else { return }
        Haptics.tap(.levelChange)
        end()
        if let bannerID = call.bannerID {
            NotificationMirror.shared.press(words, on: bannerID) { pressed in
                // If the alert could not be reached, at least bring FaceTime forward.
                if !pressed, words == Self.acceptWords { NotificationMirror.shared.launch(call.app) }
            }
        }
    }

    /// The system's alert left the screen: the call was answered elsewhere, declined or missed.
    func bannersGone(_ ids: Set<String>) {
        guard let bannerID = current?.bannerID, ids.contains(bannerID) else { return }
        end()
    }

    func end() {
        current = nil
        if case .call? = LiveActivityCenter.shared.transient?.kind {
            LiveActivityCenter.shared.dismissTransient()
        }
    }

    #if DEBUG
    /// `isla-dev://demo/call` and `call-video`: a sample call, in memory.
    func runDemo(_ name: String) {
        sequence &+= 1
        let app = NotificationAppInfo(name: "FaceTime", bundleID: "com.apple.FaceTime",
                                      url: URL(fileURLWithPath: "/System/Applications/FaceTime.app"))
        ring(IncomingCall(id: "call-\(sequence)", bannerID: nil, caller: "Ana García",
                          detail: name == "call-video" ? String(localized: "FaceTime Video") : "iPhone",
                          isVideo: name == "call-video", app: app))
    }
    #endif
}

extension NotificationMirror {
    /// Presses a button of a system banner that is still on screen.
    func press(_ names: [String], on bannerID: String, completion: @escaping @MainActor (Bool) -> Void) {
        reader.perform(.button(names), on: bannerID, completion: completion)
    }
}

// MARK: - The island

/// A call on the island: who is calling up by the camera, and the two answers under it.
struct IncomingCallIsland: View {
    let call: IncomingCall
    let model: NotchViewModel

    var body: some View {
        let notch = model.notchSize
        let ear = LiveActivityKind.call(call).earWidths(notchHeight: notch.height).left

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    CallAvatar(name: call.caller, size: 22)
                    Text(verbatim: call.caller)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: ear - 12, alignment: .leading)
                .padding(.leading, 12)
                .emerge(delay: 0.05, offset: CGSize(width: 16, height: 0))
                Color.clear.frame(width: notch.width)
                HStack(spacing: 5) {
                    Text(verbatim: call.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Image(systemName: call.isVideo ? "video.fill" : "phone.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                        .symbolEffect(.wiggle.byLayer, options: .repeat(.periodic(delay: 0.7)))
                }
                .frame(width: ear - 12, alignment: .trailing)
                .padding(.trailing, 12)
                .emerge(delay: 0.05, offset: CGSize(width: -16, height: 0))
            }
            .frame(height: notch.height)

            HStack(spacing: 10) {
                CallButton(title: "Decline", symbol: "phone.down.fill", tint: .red) { CallCenter.shared.decline() }
                CallButton(title: "Accept", symbol: call.isVideo ? "video.fill" : "phone.fill", tint: .green) { CallCenter.shared.accept() }
            }
            .padding(.horizontal, 14)
            .frame(height: LiveActivityKind.call(call).detailHeight)
            .emerge(delay: 0.12, offset: CGSize(width: 0, height: -8))
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Incoming call from \(call.caller)"))
    }
}

private struct CallButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(tint.opacity(hovering ? 1 : 0.85)))
        }
        .buttonStyle(PressSqueeze())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// The caller's initials, with rings that keep pulsing out while it rings (Core Animation,
/// so ringing costs nothing on the main thread).
struct CallAvatar: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        ZStack {
            RingPulse(color: NSColor.systemGreen)
                .frame(width: size * 1.9, height: size * 1.9)
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.85, blue: 0.55), Color(red: 0.1, green: 0.6, blue: 0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text(verbatim: initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct RingPulse: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> RingPulseView {
        let view = RingPulseView()
        view.color = color
        return view
    }

    func updateNSView(_ view: RingPulseView, context: Context) {}
}

final class RingPulseView: NSView {
    var color: NSColor = .systemGreen
    private var rings: [CAShapeLayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        if rings.isEmpty { build() }
        let side = min(bounds.width, bounds.height)
        let rect = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        for ring in rings {
            ring.frame = bounds
            ring.path = CGPath(ellipseIn: rect.insetBy(dx: side * 0.24, dy: side * 0.24), transform: nil)
        }
    }

    private func build() {
        guard let layer else { return }
        for index in 0..<2 {
            let ring = CAShapeLayer()
            ring.fillColor = nil
            ring.strokeColor = color.withAlphaComponent(0.8).cgColor
            ring.lineWidth = 1.5
            layer.addSublayer(ring)
            rings.append(ring)

            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.9
            grow.toValue = 1.9
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [grow, fade]
            group.duration = 1.6
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.8
            group.fillMode = .backwards
            ring.add(group, forKey: "pulse")
        }
    }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.masksToBounds = false
        return layer
    }
}
