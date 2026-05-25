import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class AppleHealthAudiogramWriter: ObservableObject {
    enum HealthError: LocalizedError {
        case unavailable
        case noValidPoints

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Health audiogram save is available only on supported iOS devices with HealthKit enabled."
            case .noValidPoints:
                return "No valid audiogram threshold points are available to save."
            }
        }
    }

    @Published private(set) var statusMessage = "Not connected"

    #if canImport(HealthKit) && os(iOS)
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        let audiogramType = HKObjectType.audiogramSampleType()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [audiogramType], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthError.unavailable)
                }
            }
        }

        statusMessage = "Apple Health permission granted"
    }

    func save(result: AudiogramScreeningResult) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        let sensitivityPoints = try makeSensitivityPoints(from: result.points)
        guard !sensitivityPoints.isEmpty else { throw HealthError.noValidPoints }

        let metadata: [String: Any] = [
            "TennitusCalibrationStatus": result.calibrationStatus,
            "TennitusHeadphoneModel": result.headphoneModel,
            "TennitusResultType": "Indicative screening estimate, not clinical diagnosis"
        ]
        let sample = HKAudiogramSample(
            sensitivityPoints: sensitivityPoints,
            start: result.createdAt,
            end: Date(),
            metadata: metadata
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthError.unavailable)
                }
            }
        }

        statusMessage = "Saved audiogram screening result to Apple Health"
    }

    private func makeSensitivityPoints(from points: [AudiogramThresholdPoint]) throws -> [HKAudiogramSensitivityPoint] {
        let grouped = Dictionary(grouping: points, by: { Int($0.frequencyHz) })
        return try grouped.keys.sorted().compactMap { frequency in
            guard let frequencyPoints = grouped[frequency] else { return nil }
            let left = frequencyPoints.first { $0.ear == .left }.map {
                HKQuantity(unit: .decibelHearingLevel(), doubleValue: $0.thresholdDBHL)
            }
            let right = frequencyPoints.first { $0.ear == .right }.map {
                HKQuantity(unit: .decibelHearingLevel(), doubleValue: $0.thresholdDBHL)
            }
            return try HKAudiogramSensitivityPoint(
                frequency: HKQuantity(unit: .hertz(), doubleValue: Double(frequency)),
                leftEarSensitivity: left,
                rightEarSensitivity: right
            )
        }
    }
    #else
    func requestAuthorization() async throws {
        throw HealthError.unavailable
    }

    func save(result: AudiogramScreeningResult) async throws {
        throw HealthError.unavailable
    }
    #endif
}
