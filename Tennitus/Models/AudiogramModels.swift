import Foundation

enum AudiogramEar: String, CaseIterable, Codable, Identifiable {
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

enum ASHASeverityTier: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case slight = "Slight"
    case mild = "Mild"
    case moderate = "Moderate"
    case moderatelySevere = "Moderately severe"
    case severe = "Severe"
    case profound = "Profound"
    case unavailable = "Unavailable"

    var id: String { rawValue }
}

struct AudiogramThresholdPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var ear: AudiogramEar
    var frequencyHz: Double
    var thresholdDBHL: Double
}

struct AudiogramEarSummary: Codable, Equatable {
    var pta3DBHL: Double?
    var pta4DBHL: Double?
    var highFrequencyAverageDBHL: Double?
    var worstThresholdDBHL: Double?
    var pta4Tier: ASHASeverityTier
    var worstFrequencyTier: ASHASeverityTier
}

struct AudiogramScreeningResult: Codable, Equatable {
    var createdAt = Date()
    var headphoneModel = "Unspecified"
    var calibrationStatus = "Uncalibrated screening estimate"
    var points: [AudiogramThresholdPoint]
    var leftSummary: AudiogramEarSummary
    var rightSummary: AudiogramEarSummary

    static let empty = AudiogramScreeningResult(
        points: [],
        leftSummary: AudiogramEarSummary(
            pta3DBHL: nil,
            pta4DBHL: nil,
            highFrequencyAverageDBHL: nil,
            worstThresholdDBHL: nil,
            pta4Tier: .unavailable,
            worstFrequencyTier: .unavailable
        ),
        rightSummary: AudiogramEarSummary(
            pta3DBHL: nil,
            pta4DBHL: nil,
            highFrequencyAverageDBHL: nil,
            worstThresholdDBHL: nil,
            pta4Tier: .unavailable,
            worstFrequencyTier: .unavailable
        )
    )
}
