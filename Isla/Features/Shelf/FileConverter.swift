//
//  FileConverter.swift
//  Isla
//
//  On-device conversions for files on the Shelf. Results land back on the
//  Shelf, ready to drag anywhere.
//

import AppKit
import AVFoundation
import PDFKit
import UniformTypeIdentifiers

enum ConversionTarget: String, CaseIterable, Identifiable {
    case png, jpeg, heic, tiff, pdf, mergePDF, mp4, m4a, zip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        case .tiff: "TIFF"
        case .pdf: String(localized: "Images to PDF")
        case .mergePDF: String(localized: "Merge PDFs")
        case .mp4: "MP4"
        case .m4a: String(localized: "Audio (M4A)")
        case .zip: String(localized: "Compress (ZIP)")
        }
    }

    var symbol: String {
        switch self {
        case .png, .jpeg, .heic, .tiff: "photo"
        case .pdf, .mergePDF: "doc.richtext"
        case .mp4: "film"
        case .m4a: "waveform"
        case .zip: "doc.zipper"
        }
    }

    /// Targets that make sense for the given files.
    static func available(for urls: [URL]) -> [ConversionTarget] {
        guard !urls.isEmpty else { return [] }
        var targets: [ConversionTarget] = []
        if urls.allSatisfy(\.isImageFile) { targets += [.png, .jpeg, .heic, .tiff, .pdf] }
        if urls.count > 1, urls.allSatisfy(\.isPDFFile) { targets.append(.mergePDF) }
        if urls.allSatisfy({ $0.isMovieFile }) { targets += [.mp4, .m4a] }
        if urls.allSatisfy({ $0.isAudioFile }) { targets.append(.m4a) }
        targets.append(.zip)
        return targets
    }
}

enum FileConverter {
    static let outputFolder = Storage.folder("Converted")

    @MainActor
    static func convert(_ urls: [URL], to target: ConversionTarget) {
        let shelf = ShelfStore.shared
        shelf.setBusy(String(localized: "Converting…"))
        Task.detached(priority: .userInitiated) {
            let results = await run(urls, target: target)
            await MainActor.run {
                shelf.setBusy(nil)
                if results.isEmpty {
                    NSSound.beep()
                } else {
                    shelf.add(urls: results, generated: true)
                    Haptics.tap(.levelChange)
                }
            }
        }
    }

    private static func run(_ urls: [URL], target: ConversionTarget) async -> [URL] {
        switch target {
        case .png: return urls.compactMap { convertImage($0, to: .png) }
        case .jpeg: return urls.compactMap { convertImage($0, to: .jpeg) }
        case .heic: return urls.compactMap { convertImage($0, to: .heic) }
        case .tiff: return urls.compactMap { convertImage($0, to: .tiff) }
        case .pdf: return imagesToPDF(urls).map { [$0] } ?? []
        case .mergePDF: return mergePDFs(urls).map { [$0] } ?? []
        case .mp4:
            var output: [URL] = []
            for url in urls { if let result = await exportMedia(url, preset: AVAssetExportPresetHighestQuality, type: .mp4, ext: "mp4") { output.append(result) } }
            return output
        case .m4a:
            var output: [URL] = []
            for url in urls { if let result = await exportMedia(url, preset: AVAssetExportPresetAppleM4A, type: .m4a, ext: "m4a") { output.append(result) } }
            return output
        case .zip: return zip(urls).map { [$0] } ?? []
        }
    }

    private static func destination(for source: URL, ext: String) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        var candidate = outputFolder.appendingPathComponent(base).appendingPathExtension(ext)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputFolder.appendingPathComponent("\(base) \(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }

    private static func convertImage(_ url: URL, to type: UTType) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = destination(for: url, ext: type.preferredFilenameExtension ?? "img")
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output : nil
    }

    private static func imagesToPDF(_ urls: [URL]) -> URL? {
        let document = PDFDocument()
        for url in urls {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0, let first = urls.first else { return nil }
        let output = destination(for: first, ext: "pdf")
        return document.write(to: output) ? output : nil
    }

    private static func mergePDFs(_ urls: [URL]) -> URL? {
        let merged = PDFDocument()
        for url in urls {
            guard let document = PDFDocument(url: url) else { continue }
            for index in 0..<document.pageCount {
                if let page = document.page(at: index) { merged.insert(page, at: merged.pageCount) }
            }
        }
        guard merged.pageCount > 0 else { return nil }
        let output = outputFolder.appendingPathComponent("Merged \(Date.now.formatted(.iso8601.year().month().day())).pdf")
        return merged.write(to: output) ? output : nil
    }

    private static func exportMedia(_ url: URL, preset: String, type: AVFileType, ext: String) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { return nil }
        let output = destination(for: url, ext: ext)
        do {
            try await session.export(to: output, as: type)
            return output
        } catch {
            return nil
        }
    }

    private static func zip(_ urls: [URL]) -> URL? {
        guard let first = urls.first else { return nil }
        let name = urls.count == 1 ? first.deletingPathExtension().lastPathComponent : String(localized: "Archive")
        let output = destination(for: URL(fileURLWithPath: name), ext: "zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        if urls.count == 1 {
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, output.path]
        } else {
            // Stage multiple files in one folder so they share an archive.
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("isla-zip-\(UUID().uuidString)/\(name)")
            try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            for url in urls { try? FileManager.default.copyItem(at: url, to: staging.appendingPathComponent(url.lastPathComponent)) }
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", staging.path, output.path]
        }
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? output : nil
        } catch {
            return nil
        }
    }
}
