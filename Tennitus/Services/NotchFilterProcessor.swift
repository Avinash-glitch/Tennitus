import AVFoundation
import Foundation

enum NotchFilterProcessor {
    struct Result {
        var samples: [Float]
        var url: URL?
        var analysis: AudioAnalysisSummary
    }

    static func apply(samples: [Float], sampleRate: Double, frequencyHz: Double, q: Double = 6) -> Result {
        guard !samples.isEmpty, sampleRate > 0, frequencyHz > 0 else {
            return Result(samples: samples, url: nil, analysis: SpectrumAnalyzer.analyze(samples: samples, sampleRate: sampleRate))
        }

        let filtered = biquadNotch(samples: samples, sampleRate: sampleRate, frequencyHz: frequencyHz, q: q)
        let url = writeCAF(samples: filtered, sampleRate: sampleRate)
        let analysis = SpectrumAnalyzer.analyze(samples: filtered, sampleRate: sampleRate)
        return Result(samples: filtered, url: url, analysis: analysis)
    }

    private static func biquadNotch(samples: [Float], sampleRate: Double, frequencyHz: Double, q: Double) -> [Float] {
        let nyquistSafeHz = max(1.0, sampleRate / 2 - 1)
        let clampedFrequencyHz = max(1.0, min(frequencyHz, nyquistSafeHz))
        let w0 = 2.0 * Double.pi * clampedFrequencyHz / sampleRate
        let alpha = sin(w0) / (2.0 * max(0.1, q))
        let b0 = 1.0
        let b1 = -2.0 * cos(w0)
        let b2 = 1.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(w0)
        let a2 = 1.0 - alpha

        let nb0 = b0 / a0
        let nb1 = b1 / a0
        let nb2 = b2 / a0
        let na1 = a1 / a0
        let na2 = a2 / a0

        var x1 = 0.0
        var x2 = 0.0
        var y1 = 0.0
        var y2 = 0.0
        var output: [Float] = []
        output.reserveCapacity(samples.count)

        for sample in samples {
            let x0 = Double(sample)
            let y0 = nb0 * x0 + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
            output.append(Float(max(-1, min(1, y0))))
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }

        return output
    }

    private static func writeCAF(samples: [Float], sampleRate: Double) -> URL? {
        guard !samples.isEmpty else { return nil }
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Processed", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("notched-\(UUID().uuidString).caf")
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            if let channel = buffer.floatChannelData?[0] {
                samples.withUnsafeBufferPointer { pointer in
                    channel.update(from: pointer.baseAddress!, count: samples.count)
                }
            }
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return url
        } catch {
            return nil
        }
    }
}
