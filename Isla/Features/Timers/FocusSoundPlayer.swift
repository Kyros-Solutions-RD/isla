//
//  FocusSoundPlayer.swift
//  Isla
//
//  Generates calming noise on the fly — nothing to download, nothing to stream.
//

import AVFoundation
import SwiftUI

enum FocusSound: String, CaseIterable, Identifiable {
    case brown, pink, white, rain

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .brown: "Brown Noise"
        case .pink: "Pink Noise"
        case .white: "White Noise"
        case .rain: "Soft Rain"
        }
    }

    var symbol: String {
        switch self {
        case .brown: "waveform.path"
        case .pink: "waveform"
        case .white: "aqi.medium"
        case .rain: "cloud.rain.fill"
        }
    }
}

@Observable
@MainActor
final class FocusSoundPlayer {
    static let shared = FocusSoundPlayer()

    private(set) var isPlaying = false
    var sound: FocusSound = .brown {
        didSet { generator.kind = sound }
    }
    var volume: Float = 0.35 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }
    var autoPlayDuringFocus = false

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let generator = NoiseGenerator()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?

    private init() {}

    func toggle() { isPlaying ? stop() : play() }

    func play() {
        guard !isPlaying else { return }
        if sourceNode == nil {
            let format = engine.outputNode.inputFormat(forBus: 0)
            let generator = self.generator
            let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                generator.render(frameCount: Int(frameCount), buffers: UnsafeMutableAudioBufferListPointer(audioBufferList))
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 2))
            sourceNode = node
        }
        generator.kind = sound
        engine.mainMixerNode.outputVolume = volume
        do {
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.pause()
        isPlaying = false
    }
}

/// Real-time noise synthesis. Runs on the audio thread, so it avoids locks and allocation.
final class NoiseGenerator: @unchecked Sendable {
    var kind: FocusSound = .brown

    private var brown: Float = 0
    private var pink = [Float](repeating: 0, count: 7)
    private var rainEnvelope: Float = 0
    private var seed: UInt32 = 0x1234_5678

    @inline(__always) private func random() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24) * 2 - 1
    }

    func render(frameCount: Int, buffers: UnsafeMutableAudioBufferListPointer) {
        for frame in 0..<frameCount {
            let white = random()
            var sample: Float
            switch kind {
            case .white:
                sample = white * 0.25
            case .brown:
                brown = (brown + 0.02 * white) / 1.02
                sample = brown * 3.2
            case .pink:
                pink[0] = 0.99886 * pink[0] + white * 0.0555179
                pink[1] = 0.99332 * pink[1] + white * 0.0750759
                pink[2] = 0.96900 * pink[2] + white * 0.1538520
                pink[3] = 0.86650 * pink[3] + white * 0.3104856
                pink[4] = 0.55000 * pink[4] + white * 0.5329522
                pink[5] = -0.7616 * pink[5] - white * 0.0168980
                sample = (pink[0] + pink[1] + pink[2] + pink[3] + pink[4] + pink[5] + pink[6] + white * 0.5362) * 0.06
                pink[6] = white * 0.115926
            case .rain:
                brown = (brown + 0.02 * white) / 1.02
                if random() > 0.9985 { rainEnvelope = 1 }
                rainEnvelope *= 0.993
                sample = brown * 1.8 + white * 0.08 + white * rainEnvelope * 0.25
            }
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = sample
            }
        }
    }
}
