import AVFoundation
import Foundation

@MainActor
final class RecordingPlaybackPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var activeRange: ClosedRange<Double>?

    private var player: AVAudioPlayer?
    private var stopTimer: Timer?

    func play(url: URL, range: ClosedRange<Double>? = nil) {
        stop()
        configureAudioSession()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            if let range {
                player.currentTime = max(0, range.lowerBound)
                let duration = max(0.1, range.upperBound - range.lowerBound)
                stopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.stop()
                    }
                }
            }
            self.player = player
            activeRange = range
            isPlaying = player.play()
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        stopTimer?.invalidate()
        stopTimer = nil
        player?.stop()
        player = nil
        activeRange = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stop()
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
