//
//  PocketController.swift
//  Isla
//
//  Shake the pointer while dragging files and a Pocket appears right where
//  you are. Drop the files in and they travel to the Shelf.
//

import AppKit
import SwiftUI

@MainActor
final class PocketController {
    static let shared = PocketController()

    private var panel: NSPanel?
    private var mouseUpMonitor: Any?
    private var hideTask: Task<Void, Never>?
    private let state = PocketState()

    private init() {}

    func present(at point: CGPoint) {
        let size = CGSize(width: 150, height: 150)
        let frame = NSRect(x: point.x - size.width / 2, y: point.y + 24, width: size.width, height: size.height)

        let panel = self.panel ?? makePanel(size: size)
        self.panel = panel
        panel.setFrame(frame, display: true)
        state.visible = false
        state.received = false
        panel.orderFrontRegardless()
        withAnimation(IslaMotion.open) { state.visible = true }
        Haptics.tap(.levelChange)

        hideTask?.cancel()
        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
                MainActor.assumeIsolated { PocketController.shared.scheduleHide(after: 0.9) }
            }
        }
    }

    func received(_ providers: [NSItemProvider]) {
        ShelfStore.shared.add(providers: providers)
        withAnimation(IslaMotion.activity) { state.received = true }
        Haptics.tap(.levelChange)
        scheduleHide(after: 0.7)
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            withAnimation(IslaMotion.close) { self.state.visible = false }
            try? await Task.sleep(for: .milliseconds(260))
            self.panel?.orderOut(nil)
            if let monitor = self.mouseUpMonitor {
                NSEvent.removeMonitor(monitor)
                self.mouseUpMonitor = nil
            }
        }
    }

    private func makePanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: PocketView(state: state))
        return panel
    }
}

@Observable
@MainActor
final class PocketState {
    var visible = false
    var received = false
    var targeted = false
}

private struct PocketView: View {
    @Bindable var state: PocketState

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.25)).interactive(), in: Circle())
                .frame(width: state.targeted ? 124 : 112, height: state.targeted ? 124 : 112)
            VStack(spacing: 4) {
                Image(systemName: state.received ? "checkmark" : "tray.and.arrow.down.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(state.received ? "Added" : "Pocket")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .scaleEffect(state.visible ? 1 : 0.3)
        .opacity(state.visible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(IslaMotion.snappy, value: state.targeted)
        .onDrop(of: ShelfStore.acceptedTypes, isTargeted: $state.targeted) { providers in
            PocketController.shared.received(providers)
            return true
        }
        .environment(\.colorScheme, .dark)
    }
}
