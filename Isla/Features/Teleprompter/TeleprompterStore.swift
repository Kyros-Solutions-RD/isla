//
//  TeleprompterStore.swift
//  Isla
//
//  Scripts read right under the camera, so your eyes stay on the lens. The
//  text scrolls at a steady pace or follows your voice.
//

import AVFoundation
import Speech
import SwiftUI

struct PrompterScript: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var text: String
    var updated: Date
}

@Observable
@MainActor
final class TeleprompterStore {
    static let shared = TeleprompterStore()

    private(set) var scripts: [PrompterScript] = []
    var selectedID: UUID?
    var isPlaying = false
    var offset: CGFloat = 0
    var followVoice = false {
        didSet {
            guard followVoice != oldValue else { return }
            followVoice ? follower.start() : follower.stop()
        }
    }

    @ObservationIgnored let follower = SpeechFollower()
    @ObservationIgnored private let fileName = "scripts.json"

    private init() {
        scripts = Storage.load([PrompterScript].self, from: fileName) ?? [
            PrompterScript(id: UUID(), title: String(localized: "Sample script"),
                           text: String(localized: "Hi everyone, and thanks for joining.\n\nToday I want to show you how Isla turns the notch into a place where your music, files and calendar live, right under the camera.\n\nThe teleprompter keeps your eyes close to the lens, so you look at your audience while you read.\n\nTurn on Follow My Voice and the text moves only when you speak."),
                           updated: .now)
        ]
        selectedID = scripts.first?.id
        follower.onProgress = { [weak self] fraction in
            Task { @MainActor in self?.voiceProgress = fraction }
        }
    }

    /// 0…1 position reported by the speech follower.
    var voiceProgress: Double = 0

    var selected: PrompterScript? { scripts.first { $0.id == selectedID } }

    func select(_ script: PrompterScript) {
        selectedID = script.id
        restart()
        follower.script = script.text
    }

    func restart() {
        offset = 0
        voiceProgress = 0
        follower.reset()
    }

    func togglePlay() {
        isPlaying.toggle()
        Haptics.tap()
    }

    @discardableResult
    func create() -> PrompterScript {
        let script = PrompterScript(id: UUID(), title: String(localized: "New script"), text: "", updated: .now)
        scripts.insert(script, at: 0)
        selectedID = script.id
        save()
        return script
    }

    func update(_ id: UUID, title: String? = nil, text: String? = nil) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        if let title { scripts[index].title = title }
        if let text {
            scripts[index].text = text
            follower.script = text
        }
        scripts[index].updated = .now
        save()
    }

    func delete(_ script: PrompterScript) {
        scripts.removeAll { $0.id == script.id }
        if selectedID == script.id { selectedID = scripts.first?.id }
        save()
    }

    private func save() { Storage.save(scripts, to: fileName) }
}

/// Matches recognized speech against the script to estimate reading position.
final class SpeechFollower: @unchecked Sendable {
    var onProgress: ((Double) -> Void)?
    var script: String = "" {
        didSet { words = Self.tokenize(script) }
    }

    private var words: [String] = []
    private var position = 0
    private var listening = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    func reset() { position = 0 }

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.begin() }
            }
        }
    }

    func stop() {
        // Touching `inputNode` opens the microphone (and asks for it when undecided),
        // so only a follower that is actually listening shuts the engine down.
        guard listening else { return }
        listening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func begin() {
        stop()
        guard let recognizer, recognizer.isAvailable else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try? engine.start()
        listening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.advance(with: Self.tokenize(result.bestTranscription.formattedString))
            }
            if error != nil || result?.isFinal == true {
                // Recognition sessions time out; keep listening.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, self.task != nil else { return }
                    self.begin()
                }
            }
        }
    }

    private func advance(with spoken: [String]) {
        guard !words.isEmpty, let tail = spoken.suffix(4).last else { return }
        let recent = Array(spoken.suffix(4))
        // Look a little ahead of the current position for the spoken phrase.
        let window = min(words.count, position + 40)
        var best: Int?
        for index in position..<window where words[index] == tail {
            let start = max(0, index - recent.count + 1)
            let candidate = Array(words[start...index])
            let matches = zip(candidate.reversed(), recent.reversed()).filter { $0 == $1 }.count
            if matches >= min(2, recent.count) { best = index; break }
        }
        if let best {
            position = best + 1
            onProgress?(Double(position) / Double(words.count))
        }
    }
}
