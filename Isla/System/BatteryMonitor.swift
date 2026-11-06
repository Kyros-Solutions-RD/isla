//
//  BatteryMonitor.swift
//  Isla
//

import Foundation
import IOKit.ps

@Observable
@MainActor
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    private(set) var hasBattery = false
    private(set) var level = 100
    private(set) var isCharging = false
    private(set) var isPluggedIn = false
    private(set) var minutesRemaining: Int?
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var lastAlertLevel: Int?
    @ObservationIgnored private var started = false
    #if DEBUG
    @ObservationIgnored private var demoLocked = false

    /// A full, charging battery for screenshots (`isla-dev://demo/battery-full`). Memory only.
    func applyDemo() {
        demoLocked = true
        hasBattery = true
        level = 100
        isCharging = true
        isPluggedIn = true
        minutesRemaining = nil
    }
    #endif

    private init() {}

    var statusDescription: String {
        if isCharging {
            if let minutes = minutesRemaining, minutes > 0 { return String(localized: "Charging — full in \(minutes / 60) h \(minutes % 60) min") }
            return String(localized: "Charging")
        }
        if isPluggedIn { return String(localized: "Plugged in") }
        if let minutes = minutesRemaining, minutes > 0 { return String(localized: "\(minutes / 60) h \(minutes % 60) min remaining") }
        return String(localized: "On battery")
    }

    func start() {
        guard !started else { return }
        started = true
        read(announce: false)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { BatteryMonitor.shared.read(announce: true) } }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BatteryMonitor.shared.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }

    private func read(announce: Bool) {
        #if DEBUG
        if demoLocked { return }
        #endif
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }

        var foundBattery = false
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            foundBattery = true
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let newLevel = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : current
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let timeKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = description[timeKey] as? Int

            let pluggedChanged = plugged != isPluggedIn
            let previousLevel = level

            level = newLevel
            isCharging = charging
            isPluggedIn = plugged
            minutesRemaining = (minutes ?? -1) > 0 ? minutes : nil

            guard announce, Preferences.shared.activityBattery else { continue }
            if pluggedChanged {
                LiveActivityCenter.shared.post(.power(level: newLevel, charging: charging || plugged && newLevel < 100, pluggedIn: plugged), duration: 2.6)
            } else if !plugged {
                let threshold = Preferences.shared.lowBatteryThreshold
                for mark in [threshold, 10, 5] where previousLevel > mark && newLevel <= mark && lastAlertLevel != mark {
                    lastAlertLevel = mark
                    LiveActivityCenter.shared.post(.lowBattery(level: newLevel), duration: 4)
                    break
                }
            }
            if plugged { lastAlertLevel = nil }
        }
        hasBattery = foundBattery
    }
}
