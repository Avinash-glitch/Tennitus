import AVFoundation
import Foundation

@MainActor
final class AudioEventRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var loudnessDBFS = -120.0
    @Published private(set) var permissionDenied = false
    @Published private(set) var lastError: String?
    @Published private(set) var latestRecordingURL: URL?
    @Published private(set) var recentSamples: [Float] = []

    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var sampleRate = 44_100.0
    private var timer: Timer?
    private let maximumDurationSeconds = 30

    func start() async {
        guard !isRecording else { return }

        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            permissionDenied = true
            return
        }

        do {
            try configureAudioSession()
            samples = []
            recentSamples = []
            elapsedSeconds = 0
            loudnessDBFS = -120
            latestRecordingURL = nil
            permissionDenied = false
            lastError = nil

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            sampleRate = format.sampleRate
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
                guard let self, let channelData = buffer.floatChannelData?[0] else { return }
                let frameCount = Int(buffer.frameLength)
                let chunk = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                Task { @MainActor in
                    self.appendSamples(chunk)
                }
            }

            try engine.start()
            isRecording = true
            startTimer()
        } catch {
            lastError = error.localizedDescription
            isRecording = false
        }
    }

    func stopAndAnalyse(startSeconds: Double? = nil, endSeconds: Double? = nil) -> AudioEventRecordingResult {
        stop()
        let duration = sampleRate > 0 ? Double(samples.count) / sampleRate : 0
        let start = max(0, min(startSeconds ?? 0, duration))
        let end = max(start, min(endSeconds ?? duration, duration))
        let analysis = SpectrumAnalyzer.analyze(samples: samples, sampleRate: sampleRate, startSeconds: start, endSeconds: end)
        let url = writeRecordingFile()
        latestRecordingURL = url
        return AudioEventRecordingResult(
            analysis: analysis,
            audioFileURL: url,
            durationSeconds: duration,
            samples: samples,
            sampleRate: sampleRate
        )
    }

    func analyseCurrentSamples(startSeconds: Double, endSeconds: Double) -> AudioAnalysisSummary {
        SpectrumAnalyzer.analyze(samples: samples, sampleRate: sampleRate, startSeconds: startSeconds, endSeconds: endSeconds)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRecording = false
    }

    private func appendSamples(_ chunk: [Float]) {
        samples.append(contentsOf: chunk)
        recentSamples.append(contentsOf: chunk)

        let maxSamples = Int(sampleRate) * maximumDurationSeconds
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }

        let maxRecentSamples = Int(sampleRate) * 2
        if recentSamples.count > maxRecentSamples {
            recentSamples.removeFirst(recentSamples.count - maxRecentSamples)
        }

        let rms = sqrt(chunk.reduce(Float(0)) { $0 + ($1 * $1) } / Float(max(1, chunk.count)))
        loudnessDBFS = 20 * log10(Double(max(rms, 0.000_001)))
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.maximumDurationSeconds {
                    self.stop()
                }
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }

    private func writeRecordingFile() -> URL? {
        guard !samples.isEmpty else { return nil }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("event-\(UUID().uuidString).caf")
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
            lastError = error.localizedDescription
            return nil
        }
    }
}
