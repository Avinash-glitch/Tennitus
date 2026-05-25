import AVFoundation
import Foundation

@MainActor
final class SoundPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var preset: MaskingSoundPreset = .pinkNoise
    @Published var volume = 0.35
    @Published var remainingSeconds: Int?
    
    var notchFrequencyHz: Double? {
        didSet {
            if notchFrequencyHz != oldValue {
                recalculateNotchCoefficients()
            }
        }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var timer: Timer?
    private var brownState: Float = 0
    private var pinkState: Float = 0
    private var phase: Float = 0
    
    // Biquad state variables for the audio thread
    private struct NotchCoefficients {
        let b0: Double
        let b1: Double
        let b2: Double
        let a1: Double
        let a2: Double
    }
    
    private var notchCoefficients: NotchCoefficients?
    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    private func recalculateNotchCoefficients() {
        guard let freq = notchFrequencyHz else {
            notchCoefficients = nil
            return
        }
        
        let sampleRate = 44100.0
        let q = 6.0
        let nyquistSafeHz = sampleRate / 2 - 1
        let clampedFrequencyHz = max(1.0, min(freq, nyquistSafeHz))
        let w0 = 2.0 * Double.pi * clampedFrequencyHz / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        
        let b0_temp = 1.0
        let b1_temp = -2.0 * cos(w0)
        let b2_temp = 1.0
        let a0_temp = 1.0 + alpha
        let a1_temp = -2.0 * cos(w0)
        let a2_temp = 1.0 - alpha
        
        notchCoefficients = NotchCoefficients(
            b0: b0_temp / a0_temp,
            b1: b1_temp / a0_temp,
            b2: b2_temp / a0_temp,
            a1: a1_temp / a0_temp,
            a2: a2_temp / a0_temp
        )
        
        // Reset state variables to prevent clicking/pop sounds on frequency swap
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }

    func toggle(timerMinutes: Int) {
        if isPlaying {
            stop()
        } else {
            start(timerMinutes: timerMinutes)
        }
    }

    func start(timerMinutes: Int) {
        configureAudioSession()
        installSourceNodeIfNeeded()

        do {
            try engine.start()
            isPlaying = true
            startTimer(seconds: timerMinutes * 60)
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = nil
        engine.stop()
        isPlaying = false
    }

    private func installSourceNodeIfNeeded() {
        guard sourceNode == nil else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample()
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

    private func nextSample() -> Float {
        let white = Float.random(in: -1...1)
        let shaped: Float

        switch preset {
        case .whiteNoise:
            shaped = white
        case .pinkNoise:
            pinkState = 0.98 * pinkState + 0.02 * white
            shaped = (white * 0.35) + (pinkState * 0.65)
        case .brownNoise:
            brownState = max(-1, min(1, brownState + white * 0.025))
            shaped = brownState
        case .softRain:
            pinkState = 0.92 * pinkState + 0.08 * white
            shaped = (white > 0.65 ? white * 0.7 : pinkState * 0.45)
        case .ocean:
            phase += 0.00018
            if phase > .pi * 2 { phase = 0 }
            pinkState = 0.98 * pinkState + 0.02 * white
            shaped = pinkState * (0.45 + 0.35 * sin(phase))
        case .fan:
            phase += 0.035
            if phase > .pi * 2 { phase = 0 }
            shaped = (pinkState * 0.8) + (sin(phase) * 0.12)
            pinkState = 0.96 * pinkState + 0.04 * white
        }

        var filteredSample = shaped
        if let coefs = notchCoefficients {
            let x0 = Double(shaped)
            let y0 = coefs.b0 * x0 + coefs.b1 * x1 + coefs.b2 * x2 - coefs.a1 * y1 - coefs.a2 * y2
            
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
            
            filteredSample = Float(max(-1.0, min(1.0, y0)))
        }

        return filteredSample * Float(volume)
    }

    private func startTimer(seconds: Int) {
        timer?.invalidate()
        remainingSeconds = seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                guard let remaining = self.remainingSeconds else { return }
                if remaining <= 1 {
                    self.stop()
                } else {
                    self.remainingSeconds = remaining - 1
                }
            }
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
