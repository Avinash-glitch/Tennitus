import AVFoundation
import Foundation

@MainActor
final class AudiogramTonePlayer: ObservableObject {
    @Published var frequencyHz = 1_000.0
    @Published var presentationLevelDBHL = 30.0
    @Published var ear: AudiogramEar = .left
    @Published var isPulsed = true
    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var phase = 0.0
    private var pulsePhase = 0.0

    func play(frequencyHz: Double, levelDBHL: Double, ear: AudiogramEar) {
        self.frequencyHz = frequencyHz
        self.presentationLevelDBHL = levelDBHL
        self.ear = ear
        start()
    }

    func start() {
        configureAudioSession()
        installSourceNodeIfNeeded()

        do {
            if !engine.isRunning {
                try engine.start()
            }
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
    }

    func toggle() {
        isPlaying ? stop() : start()
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }

        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frequency = max(125.0, min(12_000.0, self.frequencyHz))
            let phaseIncrement = (2.0 * Double.pi * frequency) / sampleRate
            let pulseIncrement = (2.0 * Double.pi * 2.0) / sampleRate
            let baseGain = Float(self.gain(for: self.presentationLevelDBHL))
            let targetEar = self.ear
            let pulsed = self.isPulsed

            for frame in 0..<Int(frameCount) {
                let envelope: Float
                if pulsed {
                    envelope = sin(self.pulsePhase) >= 0 ? 1.0 : 0.0
                    self.pulsePhase += pulseIncrement
                    if self.pulsePhase >= 2.0 * Double.pi {
                        self.pulsePhase -= 2.0 * Double.pi
                    }
                } else {
                    envelope = 1.0
                }

                let sample = Float(sin(self.phase)) * baseGain * envelope
                self.phase += phaseIncrement
                if self.phase >= 2.0 * Double.pi {
                    self.phase -= 2.0 * Double.pi
                }

                for (channelIndex, buffer) in ablPointer.enumerated() {
                    let data = buffer.mData?.assumingMemoryBound(to: Float.self)
                    switch targetEar {
                    case .left:
                        data?[frame] = channelIndex == 0 ? sample : 0
                    case .right:
                        data?[frame] = channelIndex == 1 ? sample : 0
                    }
                }
            }

            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    private func gain(for dbHL: Double) -> Double {
        let clamped = max(-10.0, min(100.0, dbHL))
        let dbFS = -70.0 + ((clamped + 10.0) / 110.0) * 58.0
        return min(0.32, max(0.0002, pow(10.0, dbFS / 20.0)))
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }
}
