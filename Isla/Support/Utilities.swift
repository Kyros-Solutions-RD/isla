//
//  Utilities.swift
//  Isla
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Haptics

@MainActor
enum Haptics {
    static func tap(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard Preferences.shared.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

// MARK: - Storage

enum Storage {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        // Debug builds keep their own notes, shelf and clipboard history.
        let url = base.appendingPathComponent("Isla Dev", isDirectory: true)
        #else
        let url = base.appendingPathComponent("Isla", isDirectory: true)
        #endif
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func folder(_ name: String) -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        let url = directory.appendingPathComponent(name)
        try? data.write(to: url, options: [.atomic])
    }
}

// MARK: - Shell

enum Shell {
    struct Result {
        let status: Int32
        let output: String
        let error: String
    }

    /// Runs an executable off the main thread and returns its output.
    static func run(_ launchPath: String, _ arguments: [String] = [], input: String? = nil) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                if let input {
                    let inPipe = Pipe()
                    process.standardInput = inPipe
                    inPipe.fileHandleForWriting.write(Data(input.utf8))
                    try? inPipe.fileHandleForWriting.close()
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: Result(status: -1, output: "", error: error.localizedDescription))
                    return
                }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: Result(status: process.terminationStatus,
                                                      output: String(decoding: outData, as: UTF8.self),
                                                      error: String(decoding: errData, as: UTF8.self)))
            }
        }
    }

    /// Runs an AppleScript source and returns its string result.
    @discardableResult
    static func appleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)
                continuation.resume(returning: error == nil ? (result?.stringValue ?? "") : nil)
            }
        }
    }
}

// MARK: - Formatting

extension TimeInterval {
    /// 75 → "1:15", 3725 → "1:02:05"
    var clockString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self.rounded(.down))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}

extension Date {
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Images & color

extension NSImage {
    /// A vivid representative color, used to tint the media UI.
    var vibrantColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = 12, height = 12
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var best: (score: CGFloat, color: NSColor)?
        var average = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = CGFloat(pixels[i]) / 255, g = CGFloat(pixels[i + 1]) / 255, b = CGFloat(pixels[i + 2]) / 255
            average.r += r; average.g += g; average.b += b
            let color = NSColor(red: r, green: g, blue: b, alpha: 1)
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let score = saturation * 0.7 + brightness * 0.3 - (brightness < 0.25 ? 1 : 0)
            if best == nil || score > best!.score { best = (score, color) }
        }
        if let best, best.score > 0.25 {
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            best.color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return NSColor(hue: hue, saturation: min(1, saturation * 1.05), brightness: max(0.72, brightness), alpha: 1)
        }
        let count = CGFloat(width * height)
        return NSColor(red: average.r / count, green: average.g / count, blue: average.b / count, alpha: 1)
    }
}

extension NSWorkspace {
    func appIcon(bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier, let url = urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        return icon(forFile: url.path)
    }

    func appName(bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier, let url = urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

extension URL {
    var isImageFile: Bool { (UTType(filenameExtension: pathExtension)?.conforms(to: .image)) ?? false }
    var isMovieFile: Bool { (UTType(filenameExtension: pathExtension)?.conforms(to: .movie)) ?? false }
    var isAudioFile: Bool { (UTType(filenameExtension: pathExtension)?.conforms(to: .audio)) ?? false }
    var isPDFFile: Bool { (UTType(filenameExtension: pathExtension)?.conforms(to: .pdf)) ?? false }
}

// MARK: - System Settings deep links

enum SystemSettings {
    static func open(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
