//
//  ProcessProbe.swift
//  Isla
//
//  A cheap look at the current user's own processes: name, executable,
//  arguments, working folder, start time, CPU time and memory. Everything
//  comes from libproc and sysctl, which need no permission for processes the
//  user owns. Nothing here touches the files or folders a process works in.
//

import Darwin
import Foundation

struct ProcessRecord {
    let pid: pid_t
    let ppid: pid_t
    /// Executable name as the kernel knows it (up to 32 characters).
    let name: String
    let started: Date
}

enum ProcessProbe {
    private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (UInt64(max(1, info.numer)), UInt64(max(1, info.denom)))
    }()

    private static let argumentsLimit: Int = {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctl(&mib, 2, &value, &size, nil, 0) == 0, value > 0 else { return 256 * 1024 }
        return Int(value)
    }()

    /// Every process that belongs to the current user.
    static func userProcesses() -> [ProcessRecord] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }

        let uid = getuid()
        let infoSize = Int32(MemoryLayout<proc_bsdinfo>.stride)
        var records: [ProcessRecord] = []
        records.reserveCapacity(Int(count))
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var info = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize, info.pbi_uid == uid else { continue }
            var name = string(from: info.pbi_name)
            if name.isEmpty { name = string(from: info.pbi_comm) }
            let started = Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000)
            records.append(ProcessRecord(pid: pid, ppid: pid_t(info.pbi_ppid), name: name, started: started))
        }
        return records
    }

    /// Full path of the executable.
    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The arguments the process was started with (argv), without the environment.
    static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argumentsLimit
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        // Skip the saved executable path and the padding after it.
        while index < size && buffer[index] != 0 { index += 1 }
        while index < size && buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        var start = index
        while index < size && arguments.count < Int(argc) {
            if buffer[index] == 0 {
                arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
                start = index + 1
            }
            index += 1
        }
        return arguments
    }

    /// The folder the process runs in. Only the path is read, never the folder itself.
    static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = string(from: info.pvi_cdir.vip_path)
        return path.isEmpty ? nil : path
    }

    /// Paths of the files the process has open that contain `fragment`. Only the kernel's
    /// record of the open file is read, never the file itself.
    static func openFiles(of pid: pid_t, containing fragment: String) -> [String] {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 16)
        let used = descriptors.withUnsafeMutableBytes { buffer in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard used > 0 else { return [] }
        let size = Int32(MemoryLayout<vnode_fdinfowithpath>.stride)
        var paths: [String] = []
        for descriptor in descriptors.prefix(Int(used) / stride) where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) {
            var info = vnode_fdinfowithpath()
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else { continue }
            let path = string(from: info.pvip.vip_path)
            if path.contains(fragment), !paths.contains(path) { paths.append(path) }
        }
        return paths
    }

    /// Total CPU time in nanoseconds and the memory footprint in bytes.
    static func usage(of pid: pid_t) -> (cpu: UInt64, memory: UInt64)? {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        guard result == 0 else { return nil }
        // On Apple silicon these counters are Mach ticks, not nanoseconds.
        let ticks = info.ri_user_time &+ info.ri_system_time
        return (ticks / timebase.denom &* timebase.numer, info.ri_phys_footprint)
    }

    private static func string<T>(from tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
