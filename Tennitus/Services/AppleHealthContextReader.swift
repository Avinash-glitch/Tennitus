import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class AppleHealthContextReader: ObservableObject {
    enum HealthContextError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Health sleep and hearing import is available only on supported iOS devices with HealthKit enabled."
            }
        }
    }

    @Published private(set) var statusMessage = "Not connected"

    #if canImport(HealthKit) && os(iOS)
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthContextError.unavailable }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.audiogramSampleType()
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthContextError.unavailable)
                }
            }
        }

        statusMessage = "Apple Health permission granted"
    }

    func syncContext(lookbackDays: Int = 14) async throws -> AppleHealthContext {
        try await requestAuthorization()
        let sleep = try await fetchSleepSummary(lookbackDays: lookbackDays)
        let hearing = try await fetchLatestAudiogramSummary()
        let context = AppleHealthContext(lastSyncedAt: Date(), sleep: sleep, hearing: hearing)
        statusMessage = "Synced Apple Health sleep and hearing context"
        return context
    }

    private func fetchSleepSummary(lookbackDays: Int) async throws -> AppleSleepSummary? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -lookbackDays, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samples = try await categorySamples(type: sleepType, predicate: predicate)
        let asleepSamples = samples.filter { isAsleepValue($0.value) }
        guard !asleepSamples.isEmpty else { return nil }

        let groupedByNight = Dictionary(grouping: asleepSamples) { sample in
            calendar.startOfDay(for: calendar.date(byAdding: .hour, value: -12, to: sample.startDate) ?? sample.startDate)
        }
        let nightDurations = groupedByNight.mapValues { samples in
            samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        }
        guard let latestNight = groupedByNight.keys.max(), let latestSamples = groupedByNight[latestNight] else { return nil }

        let totalHours = nightDurations.values.reduce(0, +) / 3_600
        let latestHours = latestSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3_600

        return AppleSleepSummary(
            lookbackDays: lookbackDays,
            averageAsleepHours: totalHours / Double(max(1, nightDurations.count)),
            latestNightAsleepHours: latestHours,
            latestNightStart: latestSamples.map(\.startDate).min(),
            latestNightEnd: latestSamples.map(\.endDate).max()
        )
    }

    private func fetchLatestAudiogramSummary() async throws -> AppleHearingSummary? {
        let audiogramType = HKObjectType.audiogramSampleType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples = try await audiogramSamples(type: audiogramType, sortDescriptors: [sort])
        guard let latest = samples.first else { return nil }

        let leftValues = latest.sensitivityPoints.compactMap { point -> AudiogramValue? in
            guard let sensitivity = point.leftEarSensitivity?.doubleValue(for: .decibelHearingLevel()) else { return nil }
            return AudiogramValue(
                frequencyHz: point.frequency.doubleValue(for: .hertz()),
                dbHL: sensitivity
            )
        }
        let rightValues = latest.sensitivityPoints.compactMap { point -> AudiogramValue? in
            guard let sensitivity = point.rightEarSensitivity?.doubleValue(for: .decibelHearingLevel()) else { return nil }
            return AudiogramValue(
                frequencyHz: point.frequency.doubleValue(for: .hertz()),
                dbHL: sensitivity
            )
        }

        return AppleHearingSummary(
            latestAudiogramDate: latest.endDate,
            averageLeftDBHL: appleDisplayedAverage(leftValues),
            averageRightDBHL: appleDisplayedAverage(rightValues),
            sourceName: latest.sourceRevision.source.name
        )
    }

    private func categorySamples(type: HKCategoryType, predicate: NSPredicate) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func audiogramSamples(type: HKAudiogramSampleType, sortDescriptors: [NSSortDescriptor]) async throws -> [HKAudiogramSample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKAudiogramSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sortDescriptors) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKAudiogramSample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func isAsleepValue(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        }
        return value == HKCategoryValueSleepAnalysis.asleep.rawValue
    }

    private struct AudiogramValue {
        var frequencyHz: Double
        var dbHL: Double
    }

    private func appleDisplayedAverage(_ values: [AudiogramValue]) -> Double? {
        let pta4Frequencies = [500.0, 1_000.0, 2_000.0, 4_000.0]
        let pta4Values = pta4Frequencies.compactMap { targetFrequency in
            nearestValue(to: targetFrequency, in: values)
        }

        if pta4Values.count >= 3 {
            return average(pta4Values)
        }

        return average(values.map(\.dbHL))
    }

    private func nearestValue(to targetFrequency: Double, in values: [AudiogramValue]) -> Double? {
        let toleranceRatio = 0.04
        return values
            .filter { abs($0.frequencyHz - targetFrequency) / targetFrequency <= toleranceRatio }
            .min { abs($0.frequencyHz - targetFrequency) < abs($1.frequencyHz - targetFrequency) }?
            .dbHL
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    #else
    func requestAuthorization() async throws {
        throw HealthContextError.unavailable
    }

    func syncContext(lookbackDays: Int = 14) async throws -> AppleHealthContext {
        throw HealthContextError.unavailable
    }
    #endif
}
