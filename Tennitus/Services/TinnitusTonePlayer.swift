import AVFoundation
import Foundation

@MainActor
final class TinnitusTonePlayer: ObservableObject {
    @Published var frequencyHz = 4_000.0
    @Published var volume = 0.08
    @Published var waveform: ToneWaveform = .sine
    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var phase = 0.0

    func toggle() {
        isPlaying ? stop() : start()
    }

    func start() {
        configureAudioSession()
        installSourceNodeIfNeeded()
        do {
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }

        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = (2.0 * Double.pi * self.frequencyHz) / sampleRate
            let gain = Float(self.volume)

            for frame in 0..<Int(frameCount) {
                let sample = self.sample(for: self.phase) * gain
                self.phase += phaseIncrement
                if self.phase >= 2.0 * Double.pi {
                    self.phase -= 2.0 * Double.pi
                }

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

    private func sample(for phase: Double) -> Float {
        let normalized = phase / (2.0 * Double.pi)
        switch waveform {
        case .sine:
            return Float(sin(phase))
        case .sawtooth:
            return Float((2.0 * normalized) - 1.0)
        case .triangle:
            return Float(2.0 * abs(2.0 * normalized - 1.0) - 1.0)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
