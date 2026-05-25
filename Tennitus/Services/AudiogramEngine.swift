import Foundation

enum AudiogramEngine {
    static let standardFrequencies: [Double] = [250, 500, 1_000, 2_000, 3_000, 4_000, 6_000, 8_000]

    static func makeDefaultPoints(defaultThreshold: Double = 15) -> [AudiogramThresholdPoint] {
        AudiogramEar.allCases.flatMap { ear in
            standardFrequencies.map { frequency in
                AudiogramThresholdPoint(ear: ear, frequencyHz: frequency, thresholdDBHL: defaultThreshold)
            }
        }
    }

    static func result(points: [AudiogramThresholdPoint], headphoneModel: String, calibrationStatus: String) -> AudiogramScreeningResult {
        AudiogramScreeningResult(
            headphoneModel: headphoneModel,
            calibrationStatus: calibrationStatus,
            points: points.sorted { lhs, rhs in
                if lhs.ear == rhs.ear {
                    return lhs.frequencyHz < rhs.frequencyHz
                }
                return lhs.ear.rawValue < rhs.ear.rawValue
            },
            leftSummary: summary(for: .left, points: points),
            rightSummary: summary(for: .right, points: points)
        )
    }

    static func tier(for thresholdDBHL: Double?) -> ASHASeverityTier {
        guard let thresholdDBHL else { return .unavailable }
        switch thresholdDBHL {
        case ...15:
            return .normal
        case 16...25:
            return .slight
        case 26...40:
            return .mild
        case 41...55:
            return .moderate
        case 56...70:
            return .moderatelySevere
        case 71...90:
            return .severe
        default:
            return .profound
        }
    }

    private static func summary(for ear: AudiogramEar, points: [AudiogramThresholdPoint]) -> AudiogramEarSummary {
        let earPoints = points.filter { $0.ear == ear }
        let pta3 = averageThreshold(for: [500, 1_000, 2_000], in: earPoints)
        let pta4 = averageThreshold(for: [500, 1_000, 2_000, 4_000], in: earPoints)
        let high = averageThreshold(for: [3_000, 4_000, 6_000, 8_000], in: earPoints)
        let worst = earPoints.map(\.thresholdDBHL).max()

        return AudiogramEarSummary(
            pta3DBHL: pta3,
            pta4DBHL: pta4,
            highFrequencyAverageDBHL: high,
            worstThresholdDBHL: worst,
            pta4Tier: tier(for: pta4),
            worstFrequencyTier: tier(for: worst)
        )
    }

    private static func averageThreshold(for frequencies: [Double], in points: [AudiogramThresholdPoint]) -> Double? {
        let values = frequencies.compactMap { frequency in
            points.first { Int($0.frequencyHz) == Int(frequency) }?.thresholdDBHL
        }
        guard values.count == frequencies.count else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
