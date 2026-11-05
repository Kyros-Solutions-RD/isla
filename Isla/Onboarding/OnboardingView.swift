//
//  OnboardingView.swift
//  Isla
//

import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: OnboardingView { [weak self] in self?.finish() })
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.setContentSize(NSSize(width: 760, height: 560))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        Preferences.shared.hasCompletedOnboarding = true
        window?.close()
        AppDelegate.startDeferredServices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotchManager.shared.open(.home)
        }
    }

    func windowWillClose(_ notification: Notification) {
        Preferences.shared.hasCompletedOnboarding = true
        DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        ZStack {
            OnboardingBackdrop()
            VStack(spacing: 0) {
                Group {
                    switch page {
                    case 0: welcome
                    case 1: features
                    case 2: permissions
                    default: ready
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                        removal: .opacity.combined(with: .move(edge: .leading))))
                footer
            }
            .padding(.horizontal, 44)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .frame(width: 760, height: 560)
        .animation(.smooth(duration: 0.45), value: page)
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 22) {
            AnimatedNotchDemo()
                .frame(height: 170)
            VStack(spacing: 10) {
                Text("Welcome to Isla")
                    .font(.system(size: 40, weight: .bold))
                Text("Your notch, turned into an island. Music, files, calendar, focus timers and more live right under your camera.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
    }

    private var features: some View {
        VStack(spacing: 24) {
            Text("Everything, one hover away")
                .font(.system(size: 30, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                FeatureTile(symbol: "music.note", tint: .pink, title: "Now Playing", text: "Any player, with synced lyrics.")
                FeatureTile(symbol: "tray.full.fill", tint: .teal, title: "Shelf & AirDrop", text: "Drop files on the notch, drag them anywhere.")
                FeatureTile(symbol: "calendar", tint: .red, title: "Calendar", text: "Up next and one-click meeting links.")
                FeatureTile(symbol: "doc.on.clipboard.fill", tint: .orange, title: "Clipboard", text: "Searchable history. Never passwords.")
                FeatureTile(symbol: "timer", tint: .orange, title: "Focus", text: "Pomodoro, timers and focus sounds.")
                FeatureTile(symbol: "capsule.inset.filled", tint: .purple, title: "Live Activities", text: "Charging, AirPods, volume and downloads.")
            }
        }
    }

    private var permissions: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("You're in control")
                    .font(.system(size: 30, weight: .bold))
                Text("Allow only what you want. You can change this anytime in Settings.")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(kind: kind)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    if kind != PermissionKind.allCases.last {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .padding(.vertical, 6)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 560)
        }
        .onAppear { PermissionCenter.shared.refresh() }
    }

    private var ready: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            VStack(spacing: 10) {
                Text("You're all set")
                    .font(.system(size: 34, weight: .bold))
                Text("Move the pointer to the notch, or swipe down on it with two fingers. Press ⌃⌥Space from anywhere.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            Toggle("Open Isla at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, enabled in
                    if enabled { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: index == page ? 20 : 7, height: 7)
                }
            }
            Spacer()
            if page > 0 {
                Button("Back") { page -= 1 }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            Button(page == 3 ? String(localized: "Start Using Isla") : String(localized: "Continue")) {
                if page == 3 { onFinish() } else { page += 1 }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct FeatureTile: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.gradient))
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OnboardingBackdrop: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate / 8
            Canvas { canvas, size in
                canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: .windowBackgroundColor)))
                let blobs: [(Color, Double, Double)] = [(.blue, 0.2, 0.0), (.purple, 0.75, 1.7), (.pink, 0.5, 3.1), (.teal, 0.1, 4.4)]
                for (color, x, phase) in blobs {
                    let cx = size.width * (x + 0.12 * sin(t + phase))
                    let cy = size.height * (0.5 + 0.35 * cos(t * 0.8 + phase))
                    let radius = size.width * 0.42
                    canvas.fill(Path(ellipseIn: CGRect(x: cx - radius / 2, y: cy - radius / 2, width: radius, height: radius)),
                                with: .color(color.opacity(0.22)))
                }
            }
            .blur(radius: 70)
        }
        .ignoresSafeArea()
    }
}

/// A looping preview of the notch opening into the Nook.
private struct AnimatedNotchDemo: View {
    @State private var open = false

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.22, blue: 0.45), Color(red: 0.55, green: 0.3, blue: 0.6), Color(red: 0.95, green: 0.55, blue: 0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 170)
            NotchShape(topRadius: open ? 10 : 5, bottomRadius: open ? 22 : 9)
                .fill(.black)
                .frame(width: open ? 330 : 96, height: open ? 112 : 18)
                .overlay(alignment: .top) {
                    if open {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                                .frame(width: 62, height: 62)
                            VStack(alignment: .leading, spacing: 6) {
                                Capsule().fill(.white.opacity(0.85)).frame(width: 110, height: 8)
                                Capsule().fill(.white.opacity(0.4)).frame(width: 70, height: 7)
                                Capsule().fill(.white.opacity(0.2)).frame(width: 150, height: 4)
                                HStack(spacing: 14) {
                                    Image(systemName: "backward.fill")
                                    Image(systemName: "pause.fill")
                                    Image(systemName: "forward.fill")
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 30)
                        .transition(.opacity)
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { open.toggle() }
            }
        }
    }
}
