import Foundation

struct FrequencyBandEnergy: Identifiable, Codable, Equatable {
    var id: String { label }
    var label: String
    var lowHz: Double
    var highHz: Double
    var energyDBFS: Double
    var relativeEnergy: Double
}

struct FrequencySpectrumPoint: Identifiable, Codable, Equatable {
    var id: Double { frequencyHz }
    var frequencyHz: Double
    var magnitudeDB: Double
    var normalizedMagnitude: Double
}

struct FrequencyPeak: Identifiable, Codable, Equatable {
    var id: Double { frequencyHz }
    var frequencyHz: Double
    var magnitudeDB: Double
    var normalizedMagnitude: Double
}

struct SpectrumSnapshot: Identifiable, Codable, Equatable {
    var id = UUID()
    var startSeconds: Double
    var durationSeconds: Double
    var analysis: AudioAnalysisSummary
}

struct TargetSoundMatch: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var startSeconds: Double
    var durationSeconds: Double
    var score: Double
    var confidence: String
    var dominantFrequencyHz: Double
    var topFrequencyPeaks: [FrequencyPeak]
    var rationale: [String]

    var timeRangeLabel: String {
        "\(startSeconds.formatted(.number.precision(.fractionLength(1))))-\((startSeconds + durationSeconds).formatted(.number.precision(.fractionLength(1))))s"
    }
}

struct SoundSourceDetection: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var confidence: Double
    var startSeconds: Double
    var durationSeconds: Double
    var matchedUserDescription: Bool

    var timeRangeLabel: String {
        "\(startSeconds.formatted(.number.precision(.fractionLength(1))))-\((startSeconds + durationSeconds).formatted(.number.precision(.fractionLength(1))))s"
    }
}

struct AudioAnalysisSummary: Codable, Equatable {
    var durationSeconds: Double
    var sampleRate: Double
    var rmsDBFS: Double
    var peakDBFS: Double
    var spectralCentroidHz: Double
    var dominantBandLabel: String
    var highFrequencyRatio: Double
    var transientCount: Int
    var sensitiveRangeLowHz: Double
    var sensitiveRangeHighHz: Double
    var bandEnergies: [FrequencyBandEnergy]
    var spectrumPoints: [FrequencySpectrumPoint] = []
    var dominantFrequencyHz: Double = 0
    var topFrequencyPeaks: [FrequencyPeak] = []
    var targetSoundMatches: [TargetSoundMatch] = []
    var sourceDetections: [SoundSourceDetection] = []

    init(
        durationSeconds: Double,
        sampleRate: Double,
        rmsDBFS: Double,
        peakDBFS: Double,
        spectralCentroidHz: Double,
        dominantBandLabel: String,
        highFrequencyRatio: Double,
        transientCount: Int,
        sensitiveRangeLowHz: Double,
        sensitiveRangeHighHz: Double,
        bandEnergies: [FrequencyBandEnergy],
        spectrumPoints: [FrequencySpectrumPoint] = [],
        dominantFrequencyHz: Double = 0,
        topFrequencyPeaks: [FrequencyPeak] = [],
        targetSoundMatches: [TargetSoundMatch] = [],
        sourceDetections: [SoundSourceDetection] = []
    ) {
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.rmsDBFS = rmsDBFS
        self.peakDBFS = peakDBFS
        self.spectralCentroidHz = spectralCentroidHz
        self.dominantBandLabel = dominantBandLabel
        self.highFrequencyRatio = highFrequencyRatio
        self.transientCount = transientCount
        self.sensitiveRangeLowHz = sensitiveRangeLowHz
        self.sensitiveRangeHighHz = sensitiveRangeHighHz
        self.bandEnergies = bandEnergies
        self.spectrumPoints = spectrumPoints
        self.dominantFrequencyHz = dominantFrequencyHz
        self.topFrequencyPeaks = topFrequencyPeaks
        self.targetSoundMatches = targetSoundMatches
        self.sourceDetections = sourceDetections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        rmsDBFS = try container.decode(Double.self, forKey: .rmsDBFS)
        peakDBFS = try container.decode(Double.self, forKey: .peakDBFS)
        spectralCentroidHz = try container.decode(Double.self, forKey: .spectralCentroidHz)
        dominantBandLabel = try container.decode(String.self, forKey: .dominantBandLabel)
        highFrequencyRatio = try container.decode(Double.self, forKey: .highFrequencyRatio)
        transientCount = try container.decode(Int.self, forKey: .transientCount)
        sensitiveRangeLowHz = try container.decode(Double.self, forKey: .sensitiveRangeLowHz)
        sensitiveRangeHighHz = try container.decode(Double.self, forKey: .sensitiveRangeHighHz)
        bandEnergies = try container.decode([FrequencyBandEnergy].self, forKey: .bandEnergies)
        spectrumPoints = try container.decodeIfPresent([FrequencySpectrumPoint].self, forKey: .spectrumPoints) ?? []
        dominantFrequencyHz = try container.decodeIfPresent(Double.self, forKey: .dominantFrequencyHz) ?? 0
        topFrequencyPeaks = try container.decodeIfPresent([FrequencyPeak].self, forKey: .topFrequencyPeaks) ?? []
        targetSoundMatches = try container.decodeIfPresent([TargetSoundMatch].self, forKey: .targetSoundMatches) ?? []
        sourceDetections = try container.decodeIfPresent([SoundSourceDetection].self, forKey: .sourceDetections) ?? []
    }

    var sensitiveRangeLabel: String {
        "\(Int(sensitiveRangeLowHz))-\(Int(sensitiveRangeHighHz)) Hz"
    }

    func withTargetSoundMatches(_ matches: [TargetSoundMatch]) -> AudioAnalysisSummary {
        AudioAnalysisSummary(
            durationSeconds: durationSeconds,
            sampleRate: sampleRate,
            rmsDBFS: rmsDBFS,
            peakDBFS: peakDBFS,
            spectralCentroidHz: spectralCentroidHz,
            dominantBandLabel: dominantBandLabel,
            highFrequencyRatio: highFrequencyRatio,
            transientCount: transientCount,
            sensitiveRangeLowHz: sensitiveRangeLowHz,
            sensitiveRangeHighHz: sensitiveRangeHighHz,
            bandEnergies: bandEnergies,
            spectrumPoints: spectrumPoints,
            dominantFrequencyHz: dominantFrequencyHz,
            topFrequencyPeaks: topFrequencyPeaks,
            targetSoundMatches: matches,
            sourceDetections: sourceDetections
        )
    }

    func withSourceDetections(_ detections: [SoundSourceDetection]) -> AudioAnalysisSummary {
        AudioAnalysisSummary(
            durationSeconds: durationSeconds,
            sampleRate: sampleRate,
            rmsDBFS: rmsDBFS,
            peakDBFS: peakDBFS,
            spectralCentroidHz: spectralCentroidHz,
            dominantBandLabel: dominantBandLabel,
            highFrequencyRatio: highFrequencyRatio,
            transientCount: transientCount,
            sensitiveRangeLowHz: sensitiveRangeLowHz,
            sensitiveRangeHighHz: sensitiveRangeHighHz,
            bandEnergies: bandEnergies,
            spectrumPoints: spectrumPoints,
            dominantFrequencyHz: dominantFrequencyHz,
            topFrequencyPeaks: topFrequencyPeaks,
            targetSoundMatches: targetSoundMatches,
            sourceDetections: detections
        )
    }
}

struct AudioEventRecordingResult {
    var analysis: AudioAnalysisSummary
    var audioFileURL: URL?
    var durationSeconds: Double
    var samples: [Float]
    var sampleRate: Double
}

struct AudioEventLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var recordedAt = Date()
    var audioFilePath: String?
    var selectedStartSeconds = 0.0
    var selectedEndSeconds = 0.0
    var userDescription = ""
    var backgroundDescription = ""
    var tinnitusMatchFrequencyHz: Double
    var analysis: AudioAnalysisSummary
    var localSuggestion: ComfortSessionSuggestion
    var aiSuggestion: ComfortSessionSuggestion?
}

struct ComfortSessionSuggestion: Codable, Equatable {
    var title: String
    var summary: String
    var targetFrequencyRange: String
    var suggestedSound: String
    var suggestedFrequencyHz: Double?
    var durationMinutes: Int
    var volumeGuidance: String
    var rationale: [String]
    var safetyNotes: [String]
    var confidence: String
    var disclaimer: String

    static let empty = ComfortSessionSuggestion(
        title: "No suggestion yet",
        summary: "Record an event or run AI analysis to generate a comfort session.",
        targetFrequencyRange: "Not available",
        suggestedSound: "Not available",
        suggestedFrequencyHz: nil,
        durationMinutes: 0,
        volumeGuidance: "Use only comfortable volume.",
        rationale: [],
        safetyNotes: [],
        confidence: "Low",
        disclaimer: "This is not medical advice."
    )
}
