//
//  BluetoothMonitor.swift
//  Isla
//
//  Announces AirPods, headphones, keyboards and mice as they connect, with
//  their battery when the device reports it.
//

import Foundation
import IOBluetooth

struct ConnectedDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: DeviceKind
    var battery: Int?
}

@Observable
@MainActor
final class BluetoothMonitor: NSObject {
    static let shared = BluetoothMonitor()

    private(set) var connected: [ConnectedDevice] = []

    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    @ObservationIgnored private var startedAt = Date.distantFuture

    private override init() { super.init() }

    func start() {
        guard connectNotification == nil else { return }
        startedAt = .now
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        for device in (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? [] where device.isConnected() {
            track(device, announce: false)
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // The initial burst at registration replays devices that were already connected.
        track(device, announce: Date.now.timeIntervalSince(startedAt) > 3)
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let id = device.addressString ?? device.name ?? UUID().uuidString
        notification.unregister()
        disconnectNotifications[id] = nil
        let removed = connected.first { $0.id == id }
        connected.removeAll { $0.id == id }
        if let removed, Preferences.shared.activityBluetooth {
            LiveActivityCenter.shared.post(.device(name: removed.name, device: removed.kind, connected: false, battery: nil), duration: 2.4)
        }
    }

    private func track(_ device: IOBluetoothDevice, announce: Bool) {
        let id = device.addressString ?? device.name ?? UUID().uuidString
        let name = device.name ?? String(localized: "Bluetooth Device")
        let kind = DeviceKind.guess(name: name, majorClass: device.deviceClassMajor, minorClass: device.deviceClassMinor)
        let entry = ConnectedDevice(id: id, name: name, kind: kind, battery: Self.battery(of: device))

        if let index = connected.firstIndex(where: { $0.id == id }) {
            connected[index] = entry
        } else {
            connected.append(entry)
        }
        if disconnectNotifications[id] == nil {
            disconnectNotifications[id] = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        }
        guard announce, Preferences.shared.activityBluetooth else { return }
        LiveActivityCenter.shared.post(.device(name: name, device: kind, connected: true, battery: entry.battery), duration: 3)

        // Battery levels for Apple accessories arrive a moment after connecting.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, let index = self.connected.firstIndex(where: { $0.id == id }) else { return }
            let level = Self.battery(of: device)
            if level != self.connected[index].battery {
                self.connected[index].battery = level
            }
        }
    }

    /// Reads battery levels that Apple accessories publish on the device object.
    private static func battery(of device: IOBluetoothDevice) -> Int? {
        let keys = ["batteryPercentSingle", "batteryPercentCombined", "batteryPercentLeft", "batteryPercentRight", "batteryPercentCase"]
        var values: [Int] = []
        for key in keys where device.responds(to: NSSelectorFromString(key)) {
            if let number = device.value(forKey: key) as? NSNumber, number.intValue > 0, number.intValue <= 100 {
                if key == "batteryPercentCase" && !values.isEmpty { continue }
                values.append(number.intValue)
            }
        }
        return values.min()
    }
}
