//
//  Permissions.swift
//  Isla
//
//  Isla asks only for what a feature needs, and only when you turn it on.
//

import AppKit
import AVFoundation
import CoreLocation
import EventKit
import SwiftUI

enum PermissionKind: String, CaseIterable, Identifiable {
    case calendar, reminders, camera, location, accessibility, microphone

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .camera: "Camera"
        case .location: "Location"
        case .accessibility: "Accessibility"
        case .microphone: "Microphone & Speech"
        }
    }

    var reason: LocalizedStringKey {
        switch self {
        case .calendar: "Upcoming events and meeting countdowns."
        case .reminders: "Tasks synced with your Reminders lists."
        case .camera: "The Mirror, to check yourself before a call."
        case .location: "Local weather in the Nook."
        case .accessibility: "Show your notifications in the notch, replace the volume and brightness overlay, and paste from the clipboard history."
        case .microphone: "Lets the Teleprompter follow your voice."
        }
    }

    var symbol: String {
        switch self {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .camera: "camera.fill"
        case .location: "location.fill"
        case .accessibility: "accessibility"
        case .microphone: "mic.fill"
        }
    }

    var tint: Color {
        switch self {
        case .calendar: .red
        case .reminders: .orange
        case .camera: .green
        case .location: .blue
        case .accessibility: .indigo
        case .microphone: .pink
        }
    }
}

@Observable
@MainActor
final class PermissionCenter {
    static let shared = PermissionCenter()

    private(set) var granted: Set<PermissionKind> = []

    /// Accessibility has no change notification, and the other grants change in System
    /// Settings while Isla is in the background. Re-check when Isla comes back to the
    /// front, and every second while a view that shows permissions is on screen.
    private var watchers = 0
    private var timer: Timer?

    private init() {
        refresh()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PermissionCenter.shared.refresh() }
        }
    }

    func startWatching() {
        watchers += 1
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { PermissionCenter.shared.refresh() }
        }
    }

    func stopWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        var result = Set<PermissionKind>()
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { result.insert(.calendar) }
        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess { result.insert(.reminders) }
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { result.insert(.camera) }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { result.insert(.microphone) }
        let location = CLLocationManager().authorizationStatus
        if location == .authorizedAlways || location == .authorized { result.insert(.location) }
        if AXIsProcessTrusted() { result.insert(.accessibility) }
        if result != granted { granted = result }
    }

    func isGranted(_ kind: PermissionKind) -> Bool { granted.contains(kind) }

    /// The system's own answer for each permission (0 = not asked yet, 2 = denied, 3 = allowed…),
    /// for the permission report.
    static func rawStatuses() -> String {
        [
            "calendar=\(EKEventStore.authorizationStatus(for: .event).rawValue)",
            "reminders=\(EKEventStore.authorizationStatus(for: .reminder).rawValue)",
            "camera=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)",
            "microphone=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)",
            "location=\(CLLocationManager().authorizationStatus.rawValue)",
            "accessibility=\(AXIsProcessTrusted() ? 1 : 0)",
        ].joined(separator: " ")
    }

    func request(_ kind: PermissionKind) {
        Task {
            switch kind {
            case .calendar:
                await CalendarService.shared.requestAccess()
            case .reminders:
                await TasksStore.shared.requestRemindersAccess()
            case .camera:
                _ = await AVCaptureDevice.requestAccess(for: .video)
            case .microphone:
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            case .location:
                WeatherService.shared.requestAccess()
            case .accessibility:
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                SystemSettings.open("Privacy_Accessibility")
            }
            try? await Task.sleep(for: .milliseconds(600))
            refresh()
        }
    }
}
