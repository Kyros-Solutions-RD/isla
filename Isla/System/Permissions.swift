//
//  Permissions.swift
//  Isla
//
//  Isla asks only for what a feature needs, and only when you turn it on.
//

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
        case .accessibility: "Replace the volume and brightness overlay, and paste from the clipboard history."
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

    private init() { refresh() }

    func refresh() {
        var result = Set<PermissionKind>()
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { result.insert(.calendar) }
        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess { result.insert(.reminders) }
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { result.insert(.camera) }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { result.insert(.microphone) }
        let location = CLLocationManager().authorizationStatus
        if location == .authorizedAlways || location == .authorized { result.insert(.location) }
        if AXIsProcessTrusted() { result.insert(.accessibility) }
        granted = result
    }

    func isGranted(_ kind: PermissionKind) -> Bool { granted.contains(kind) }

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
