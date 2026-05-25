import AVFoundation
import Foundation

@MainActor
final class TinnitusReferenceSoundPlayer: ObservableObject {
    @Published private(set) var playingType: SoundType?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var currentType: SoundType = .ringing
    private var phase = 0.0
    private var secondaryPhase = 0.0
    private var lfoPhase = 0.0
    private var noiseState = 0.0
    private var stopTask: Task<Void, Never>?

    func toggle(_ type: SoundType) {
        if playingType == type {
            stop()
        } else {
            play(type)
        }
    }

    func play(_ type: SoundType) {
        stopTask?.cancel()
        currentType = type
        resetState()
        configureAudioSession()
        installSourceNodeIfNeeded()

        do {
            if !engine.isRunning {
                try engine.start()
            }
            playingType = type
            stopTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    guard let self, self.playingType == type else { return }
                    self.stop()
                }
            }
        } catch {
            playingType = nil
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        engine.stop()
        playingType = nil
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }

        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample(sampleRate: sampleRate)
                for buffer in ablPointer {
                    let data = buffer.mData?.assumingMemoryBound(to: Float.self)
                    data?[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    private func nextSample(sampleRate: Double) -> Float {
        let sample: Double
        switch currentType {
        case .ringing:
            sample = sine(6_000, sampleRate: sampleRate)
        case .buzzing:
            let carrier = softSaw(650, sampleRate: sampleRate)
            let modulation = 0.55 + (0.45 * sinAdvance(42, phase: &lfoPhase, sampleRate: sampleRate))
            sample = carrier * modulation
        case .hissing:
            let white = Double.random(in: -1...1)
            noiseState = (0.82 * noiseState) + (0.18 * white)
            sample = (white - noiseState) * 0.75
        case .whooshing:
            let white = Double.random(in: -1...1)
            noiseState = (0.985 * noiseState) + (0.015 * white)
            let swell = 0.35 + (0.65 * ((sinAdvance(0.55, phase: &lfoPhase, sampleRate: sampleRate) + 1) / 2))
            sample = noiseState * swell
        case .pulsing:
            let pulse = pow(max(0, sinAdvance(1.2, phase: &lfoPhase, sampleRate: sampleRate)), 3)
            sample = sine(180, sampleRate: sampleRate) * pulse
        case .multiple:
            let toneA = sine(4_000, sampleRate: sampleRate)
            let toneB = sine(7_200, phase: &secondaryPhase, sampleRate: sampleRate)
            let white = Double.random(in: -1...1) * 0.12
            sample = (toneA * 0.55) + (toneB * 0.25) + white
        case .other:
            sample = sine(1_000, sampleRate: sampleRate) * 0.55
        }

        return Float(max(-1, min(1, sample)) * 0.07)
    }

    private func sine(_ frequency: Double, sampleRate: Double) -> Double {
        sine(frequency, phase: &phase, sampleRate: sampleRate)
    }

    private func sine(_ frequency: Double, phase: inout Double, sampleRate: Double) -> Double {
        sinAdvance(frequency, phase: &phase, sampleRate: sampleRate)
    }

    private func softSaw(_ frequency: Double, sampleRate: Double) -> Double {
        let normalized = phase / (2.0 * Double.pi)
        advance(&phase, frequency: frequency, sampleRate: sampleRate)
        return tanh(((2.0 * normalized) - 1.0) * 2.2)
    }

    private func sinAdvance(_ frequency: Double, phase: inout Double, sampleRate: Double) -> Double {
        let value = sin(phase)
        advance(&phase, frequency: frequency, sampleRate: sampleRate)
        return value
    }

    private func advance(_ phase: inout Double, frequency: Double, sampleRate: Double) {
        phase += (2.0 * Double.pi * frequency) / sampleRate
        if phase >= 2.0 * Double.pi {
            phase -= 2.0 * Double.pi
        }
    }

    private func resetState() {
        phase = 0
        secondaryPhase = 0
        lfoPhase = 0
        noiseState = 0
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
