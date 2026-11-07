//
//  SystemStats.swift
//  Isla
//
//  CPU, memory, network, disk and thermal state, read with the same calls Activity Monitor
//  uses (host_processor_info, host_statistics64, the interface list) and no permission at
//  all. It only measures while something on screen shows it, about once a second.
//

import Darwin
import Foundation
import SwiftUI

@Observable
@MainActor
final class SystemStats {
    static let shared = SystemStats()

    /// 0…1, all cores together.
    private(set) var cpu: Double = 0
    private(set) var cpuHistory: [Double] = Array(repeating: 0, count: SystemStats.historyLength)
    private(set) var memoryUsed: UInt64 = 0
    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    /// Bytes per second, down and up, over Wi-Fi and Ethernet.
    private(set) var download: Double = 0
    private(set) var upload: Double = 0
    private(set) var downloadHistory: [Double] = Array(repeating: 0, count: SystemStats.historyLength)
    private(set) var diskFree: Int64 = 0
    private(set) var diskTotal: Int64 = 0
    private(set) var thermal: ProcessInfo.ThermalState = .nominal

    static let historyLength = 40

    var memoryFraction: Double { memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0 }
    var diskUsedFraction: Double { diskTotal > 0 ? 1 - Double(diskFree) / Double(diskTotal) : 0 }

    @ObservationIgnored private var watchers: Set<String> = []
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var previousTicks: (busy: UInt64, total: UInt64)?
    @ObservationIgnored private var previousBytes: (down: UInt64, up: UInt64, time: TimeInterval)?
    @ObservationIgnored private var lastDiskCheck: TimeInterval = 0

    private init() {}

    // MARK: Who is looking

    /// Something on screen shows the numbers: keep them fresh.
    func watch(_ id: String) {
        watchers.insert(id)
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.sample()
                // Quicker while the Nook shows the widget; the ears around the closed notch
                // only need a glance every few seconds.
                try? await Task.sleep(for: .seconds(self.watchers.contains("widget") ? 2 : 3))
            }
        }
    }

    func unwatch(_ id: String) {
        watchers.remove(id)
        guard watchers.isEmpty else { return }
        loop?.cancel()
        loop = nil
        previousTicks = nil
        previousBytes = nil
    }

    // MARK: Sampling

    private func sample() {
        if let value = Self.cpuLoad(previous: &previousTicks) {
            cpu = value
            cpuHistory.append(value)
            cpuHistory.removeFirst(max(0, cpuHistory.count - Self.historyLength))
        }
        // Only touch what changed: every assignment redraws the views that read it.
        if let memory = Self.memoryInUse(), abs(Double(memory) - Double(memoryUsed)) > 8_000_000 { memoryUsed = memory }
        if let bytes = Self.networkBytes() {
            let now = ProcessInfo.processInfo.systemUptime
            if let previous = previousBytes, now > previous.time, bytes.down >= previous.down, bytes.up >= previous.up {
                let elapsed = now - previous.time
                download = Double(bytes.down - previous.down) / elapsed
                upload = Double(bytes.up - previous.up) / elapsed
                downloadHistory.append(download)
                downloadHistory.removeFirst(max(0, downloadHistory.count - Self.historyLength))
            }
            previousBytes = (bytes.down, bytes.up, now)
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastDiskCheck > 20 {
            lastDiskCheck = now
            let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            if let free = values?.volumeAvailableCapacityForImportantUsage, free != diskFree { diskFree = free }
            if let total = values?.volumeTotalCapacity, Int64(total) != diskTotal { diskTotal = Int64(total) }
        }
        let state = ProcessInfo.processInfo.thermalState
        if state != thermal { thermal = state }
    }

    /// Share of all cores' time spent working since the previous sample.
    private static func cpuLoad(previous: inout (busy: UInt64, total: UInt64)?) -> Double? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        var busy: UInt64 = 0, total: UInt64 = 0
        for core in 0..<Int(count) {
            let base = core * Int(CPU_STATE_MAX)
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            busy += user + system + nice
            total += user + system + nice + idle
        }
        defer { previous = (busy, total) }
        guard let last = previous, total > last.total, busy >= last.busy else { return nil }
        return min(1, max(0, Double(busy - last.busy) / Double(total - last.total)))
    }

    /// What Activity Monitor calls "Memory Used": app memory, wired and compressed.
    private static func memoryInUse() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) - min(UInt64(stats.internal_page_count), UInt64(stats.purgeable_count))
        return (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }

    /// Bytes in and out of the Wi-Fi and Ethernet interfaces, with 64-bit counters
    /// (the ones from getifaddrs wrap at 4 GB).
    private static func networkBytes() -> (down: UInt64, up: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }
        var down: UInt64 = 0, up: UInt64 = 0
        var names: [UInt16: Bool] = [:]
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let header = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self) }
            if Int32(header.ifm_type) == RTM_IFINFO2 {
                let message = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self) }
                let index = message.ifm_index
                if names[index] == nil {
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    names[index] = if_indextoname(UInt32(index), &name) != nil && String(cString: name).hasPrefix("en")
                }
                if names[index] == true {
                    down += message.ifm_data.ifi_ibytes
                    up += message.ifm_data.ifi_obytes
                }
            }
            guard header.ifm_msglen > 0 else { break }
            offset += Int(header.ifm_msglen)
        }
        return (down, up)
    }

    // MARK: Formatting

    static func rate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = bytesPerSecond < 1_000_000 ? [.useKB] : [.useMB, .useGB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(max(0, bytesPerSecond))) + "/s"
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .memory)
    }
}
