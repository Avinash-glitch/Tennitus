import Foundation

#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

enum SoundSourceDetectionService {
    static func detect(audioFileURL: URL, userDescription: String) async -> [SoundSourceDetection] {
        #if canImport(SoundAnalysis)
        await SoundAnalysisDetector().detect(audioFileURL: audioFileURL, userDescription: userDescription)
        #else
        []
        #endif
    }
}

#if canImport(SoundAnalysis)
private final class SoundAnalysisDetector {
    func detect(audioFileURL: URL, userDescription: String) async -> [SoundSourceDetection] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let analyzer = try SNAudioFileAnalyzer(url: audioFileURL)
                    let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                    request.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 48_000)
                    request.overlapFactor = 0.5

                    let observer = SoundSourceObserver(userDescription: userDescription)
                    try analyzer.add(request, withObserver: observer)
                    analyzer.analyze {
                        _ in continuation.resume(returning: observer.bestDetections())
                    }
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

private final class SoundSourceObserver: NSObject, SNResultsObserving {
    private let terms: Set<String>
    private var detections: [SoundSourceDetection] = []
    private let lock = NSLock()

    init(userDescription: String) {
        self.terms = SoundSourceObserver.searchTerms(from: userDescription)
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }

        let start = result.timeRange.start.seconds
        let duration = result.timeRange.duration.seconds
        let newDetections = result.classifications.prefix(8).map { classification in
            SoundSourceDetection(
                label: classification.identifier,
                confidence: classification.confidence,
                startSeconds: start.isFinite ? start : 0,
                durationSeconds: duration.isFinite ? duration : 0,
                matchedUserDescription: matches(classification.identifier)
            )
        }

        lock.lock()
        detections.append(contentsOf: newDetections)
        lock.unlock()
    }

    func bestDetections() -> [SoundSourceDetection] {
        lock.lock()
        defer { lock.unlock() }

        let grouped = Dictionary(grouping: detections) { $0.label }
        let bestPerLabel = grouped.compactMap { _, values in
            values.max { lhs, rhs in
                let lhsScore = lhs.confidence + (lhs.matchedUserDescription ? 0.35 : 0)
                let rhsScore = rhs.confidence + (rhs.matchedUserDescription ? 0.35 : 0)
                return lhsScore < rhsScore
            }
        }

        return bestPerLabel
            .filter { $0.confidence >= 0.08 || $0.matchedUserDescription }
            .sorted { lhs, rhs in
                let lhsScore = lhs.confidence + (lhs.matchedUserDescription ? 0.35 : 0)
                let rhsScore = rhs.confidence + (rhs.matchedUserDescription ? 0.35 : 0)
                return lhsScore > rhsScore
            }
            .prefix(6)
            .map { $0 }
    }

    private func matches(_ identifier: String) -> Bool {
        let normalized = identifier.lowercased()
        return terms.contains { normalized.contains($0) }
    }

    private static func searchTerms(from description: String) -> Set<String> {
        let normalized = description.lowercased()
        var terms = Set(
            normalized
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 }
        )

        if normalized.contains("electric guitar") || normalized.contains("guitar") {
            terms.formUnion(["guitar", "electric", "music", "string"])
        }
        if normalized.contains("voice") || normalized.contains("speech") || normalized.contains("vocal") {
            terms.formUnion(["speech", "voice", "singing", "vocal"])
        }
        if normalized.contains("cymbal") || normalized.contains("hiss") || normalized.contains("sharp") {
            terms.formUnion(["cymbal", "hiss", "music"])
        }
        if normalized.contains("alarm") || normalized.contains("beep") {
            terms.formUnion(["alarm", "beep", "tone"])
        }

        return terms
    }
}
#endif
