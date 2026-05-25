import Foundation

enum TriggerWeightingEngine {
    static func calculate(store: AppStore, analysis: AudioAnalysisSummary? = nil) -> WeightedTriggerScore {
        let latestCheckIn = store.latestCheckIn
        let analysis = analysis ?? store.audioEvents.first?.analysis

        let factors = [
            factor(
                name: "Poor sleep",
                weight: 0.25,
                value: sleepValue(context: store.appleHealthContext, checkIn: latestCheckIn),
                evidence: sleepEvidence(context: store.appleHealthContext, checkIn: latestCheckIn)
            ),
            factor(
                name: "Stress/distress",
                weight: 0.20,
                value: stressValue(checkIn: latestCheckIn),
                evidence: stressEvidence(checkIn: latestCheckIn)
            ),
            factor(
                name: "Sensitive-band energy",
                weight: 0.25,
                value: sensitiveBandValue(analysis: analysis, profile: store.profile),
                evidence: sensitiveBandEvidence(analysis: analysis, profile: store.profile)
            ),
            factor(
                name: "Noise/headphones",
                weight: 0.15,
                value: exposureValue(checkIn: latestCheckIn),
                evidence: exposureEvidence(checkIn: latestCheckIn)
            ),
            factor(
                name: "Recent spike history",
                weight: 0.10,
                value: recentSpikeValue(spikes: store.spikes),
                evidence: recentSpikeEvidence(spikes: store.spikes)
            ),
            factor(
                name: "Hearing context",
                weight: 0.05,
                value: hearingValue(context: store.appleHealthContext),
                evidence: hearingEvidence(context: store.appleHealthContext)
            )
        ]

        let score = factors.reduce(0) { $0 + $1.contribution }
        return WeightedTriggerScore(score: score, tier: tier(for: score), factors: factors)
    }

    private static func factor(name: String, weight: Double, value: Double, evidence: String) -> WeightedTriggerScore.Factor {
        let clampedValue = clamp(value)
        return WeightedTriggerScore.Factor(
            name: name,
            weight: weight,
            value: clampedValue,
            contribution: clampedValue * weight,
            evidence: evidence
        )
    }

    private static func sleepValue(context: AppleHealthContext, checkIn: DailyCheckIn?) -> Double {
        if let sleep = context.sleep {
            return clamp((7.5 - sleep.latestNightAsleepHours) / 4.0)
        }
        guard let checkIn else { return 0.3 }
        return clamp(Double(10 - checkIn.sleepQuality) / 10.0)
    }

    private static func sleepEvidence(context: AppleHealthContext, checkIn: DailyCheckIn?) -> String {
        if let sleep = context.sleep {
            return "Apple Health latest sleep \(sleep.latestNightAsleepHours.formatted(.number.precision(.fractionLength(1))))h, 14-day avg \(sleep.averageAsleepHours.formatted(.number.precision(.fractionLength(1))))h."
        }
        if let checkIn {
            return "Manual sleep quality \(checkIn.sleepQuality)/10."
        }
        return "No sleep data yet."
    }

    private static func stressValue(checkIn: DailyCheckIn?) -> Double {
        guard let checkIn else { return 0.3 }
        return clamp((Double(checkIn.stress) * 0.65 + Double(checkIn.distress) * 0.35) / 10.0)
    }

    private static func stressEvidence(checkIn: DailyCheckIn?) -> String {
        guard let checkIn else { return "No recent check-in." }
        return "Stress \(checkIn.stress)/10 and distress \(checkIn.distress)/10."
    }

    private static func sensitiveBandValue(analysis: AudioAnalysisSummary?, profile: TinnitusProfile) -> Double {
        guard let analysis else { return 0.25 }
        let low = profile.toneMatchLowHz ?? analysis.sensitiveRangeLowHz
        let high = profile.toneMatchHighHz ?? analysis.sensitiveRangeHighHz
        let overlapping = analysis.bandEnergies.filter { bandsOverlap($0.lowHz...$0.highHz, low...high) }
        guard !overlapping.isEmpty else { return 0.2 }
        return clamp(overlapping.map(\.relativeEnergy).max() ?? 0)
    }

    private static func sensitiveBandEvidence(analysis: AudioAnalysisSummary?, profile: TinnitusProfile) -> String {
        guard let analysis else { return "No recorded audio analysis yet." }
        let low = profile.toneMatchLowHz ?? analysis.sensitiveRangeLowHz
        let high = profile.toneMatchHighHz ?? analysis.sensitiveRangeHighHz
        return "Dominant band \(analysis.dominantBandLabel), checked against \(formatHz(low))-\(formatHz(high))."
    }

    private static func exposureValue(checkIn: DailyCheckIn?) -> Double {
        guard let checkIn else { return 0.3 }
        let noise: Double
        switch checkIn.noiseExposure {
        case .quiet: noise = 0.05
        case .moderate: noise = 0.35
        case .loud: noise = 0.75
        case .veryLoud: noise = 1.0
        }

        let headphones: Double
        switch checkIn.headphoneUse {
        case .none: headphones = 0.0
        case .underOneHour: headphones = 0.2
        case .oneToThreeHours: headphones = 0.55
        case .threePlusHours: headphones = 0.85
        }
        return clamp((noise * 0.65) + (headphones * 0.35))
    }

    private static func exposureEvidence(checkIn: DailyCheckIn?) -> String {
        guard let checkIn else { return "No recent exposure check-in." }
        return "Noise \(checkIn.noiseExposure.rawValue), headphones \(checkIn.headphoneUse.rawValue)."
    }

    private static func recentSpikeValue(spikes: [SpikeLog]) -> Double {
        let recent = recentSpikes(spikes)
        return clamp(Double(recent.count) / 5.0)
    }

    private static func recentSpikeEvidence(spikes: [SpikeLog]) -> String {
        "\(recentSpikes(spikes).count) spike logs in the last 7 days."
    }

    private static func hearingValue(context: AppleHealthContext) -> Double {
        guard let hearing = context.hearing else { return 0.2 }
        let left = hearing.averageLeftDBHL
        let right = hearing.averageRightDBHL
        let averageThreshold = [left, right].compactMap { $0 }.average ?? 0
        let asymmetry = abs((left ?? averageThreshold) - (right ?? averageThreshold))
        return clamp((averageThreshold - 15) / 45 + asymmetry / 60)
    }

    private static func hearingEvidence(context: AppleHealthContext) -> String {
        guard let hearing = context.hearing else { return "No Apple Health audiogram synced." }
        let left = hearing.averageLeftDBHL.map { "\($0.formatted(.number.precision(.fractionLength(0)))) dB HL" } ?? "--"
        let right = hearing.averageRightDBHL.map { "\($0.formatted(.number.precision(.fractionLength(0)))) dB HL" } ?? "--"
        return "Apple Health audiogram averages: L \(left), R \(right)."
    }

    private static func tier(for score: Double) -> String {
        switch score {
        case ..<0.33: return "Low"
        case ..<0.66: return "Medium"
        default: return "High"
        }
    }

    private static func recentSpikes(_ spikes: [SpikeLog]) -> [SpikeLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return spikes.filter { $0.startedAt >= cutoff }
    }

    private static func bandsOverlap(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func formatHz(_ hz: Double) -> String {
        hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz)) Hz"
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
