import Foundation

enum TinnitusLaterality: String, CaseIterable, Codable, Identifiable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
    case insideHead = "Inside head"
    case unsure = "Unsure"

    var id: String { rawValue }
}

enum SoundType: String, CaseIterable, Codable, Identifiable {
    case ringing = "Ringing"
    case buzzing = "Buzzing"
    case hissing = "Hissing"
    case whooshing = "Whooshing"
    case pulsing = "Pulsing"
    case multiple = "Multiple"
    case other = "Other"

    var id: String { rawValue }
}

enum ToneWaveform: String, CaseIterable, Codable, Identifiable {
    case sine = "Sine"
    case sawtooth = "Sawtooth"
    case triangle = "Triangle"

    var id: String { rawValue }
}

enum ExposureBucket: String, CaseIterable, Codable, Identifiable {
    case quiet = "Quiet"
    case moderate = "Moderate"
    case loud = "Loud"
    case veryLoud = "Very loud"

    var id: String { rawValue }
}

enum DurationBucket: String, CaseIterable, Codable, Identifiable {
    case none = "None"
    case underOneHour = "< 1 hour"
    case oneToThreeHours = "1-3 hours"
    case threePlusHours = "3+ hours"

    var id: String { rawValue }
}

enum TriggerTag: String, CaseIterable, Codable, Identifiable {
    case noise = "Noise"
    case headphones = "Headphones"
    case stress = "Stress"
    case poorSleep = "Poor sleep"
    case caffeine = "Caffeine"
    case alcohol = "Alcohol"
    case jawNeck = "Jaw/neck"
    case illness = "Illness"
    case medication = "Medication"
    case unknown = "Unknown"

    var id: String { rawValue }
}

enum MaskingSoundPreset: String, CaseIterable, Codable, Identifiable {
    case whiteNoise = "White noise"
    case pinkNoise = "Pink noise"
    case brownNoise = "Brown noise"
    case softRain = "Soft rain"
    case ocean = "Ocean"
    case fan = "Fan"

    var id: String { rawValue }
}

struct TinnitusProfile: Codable, Equatable {
    var createdAt = Date()
    var laterality: TinnitusLaterality = .unsure
    var soundType: SoundType = .ringing
    var savedToneFrequencyHz: Double?
    var savedToneWaveform: ToneWaveform?
    var toneMatchLowHz: Double?
    var toneMatchHighHz: Double?
    var baselineLoudness = 4
    var baselineDistress = 4
    var sleepImpact = 4
    var mainGoal = "Prepare appointment"
    var detectedSubtype: TinnitusSubtype? = nil
    var redFlags: RedFlagScreeningResult? = nil
}

struct RedFlagScreeningResult: Codable, Equatable {
    var answeredAt = Date()
    var heartbeatSynced = false
    var suddenHearingLoss = false
    var oneSidedNew = false
    var dizziness = false
    var earPain = false
    var neurologicalSymptoms = false
    var severeDistress = false
    
    var hasRedFlags: Bool {
        heartbeatSynced || suddenHearingLoss || oneSidedNew || dizziness || earPain || neurologicalSymptoms || severeDistress
    }
}

struct DailyCheckIn: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var loudness = 4
    var distress = 4
    var sleepQuality = 6
    var stress = 4
    var mood = 6
    var headphoneUse: DurationBucket = .none
    var noiseExposure: ExposureBucket = .moderate
    var notes = ""
}

struct SpikeLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var startedAt = Date()
    var endedAt: Date?
    var loudness = 7
    var distress = 7
    var context = "Home"
    var triggers: Set<TriggerTag> = []
    var notes = ""
}

struct WeeklyInsight: Equatable {
    var checkInCount: Int
    var spikeCount: Int
    var averageLoudness: Double
    var averageDistress: Double
    var averageSleep: Double
    var averageStress: Double
    var confidence: String
    var headline: String
    var observations: [String]
}

struct AIResponseLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var source = "AI Proxy"
    var tinnitusMatchFrequencyHz: Double
    var userDescription: String
    var backgroundDescription: String
    var analysis: AudioAnalysisSummary
    var suggestion: ComfortSessionSuggestion
}

struct AppleHealthDataPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: Kind
    var startDate: Date
    var endDate: Date?
    var value: Double
    var unit: String
    var sourceName: String?
    var metadata: [String: String] = [:]

    enum Kind: String, Codable, CaseIterable {
        case sleepSegment
        case audiogramLeft
        case audiogramRight
    }
}

struct AppleHealthContext: Codable, Equatable {
    var lastSyncedAt: Date?
    var sleep: AppleSleepSummary?
    var hearing: AppleHearingSummary?
    var dataPoints: [AppleHealthDataPoint] = []

    static let empty = AppleHealthContext()
}

extension AppleHealthContext {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        sleep = try container.decodeIfPresent(AppleSleepSummary.self, forKey: .sleep)
        hearing = try container.decodeIfPresent(AppleHearingSummary.self, forKey: .hearing)
        dataPoints = try container.decodeIfPresent([AppleHealthDataPoint].self, forKey: .dataPoints) ?? []
    }
}

struct AppleSleepSummary: Codable, Equatable {
    var lookbackDays: Int
    var averageAsleepHours: Double
    var latestNightAsleepHours: Double
    var latestNightStart: Date?
    var latestNightEnd: Date?
}

struct AppleHearingSummary: Codable, Equatable {
    var latestAudiogramDate: Date?
    var averageLeftDBHL: Double?
    var averageRightDBHL: Double?
    var sourceName: String?
}

struct WeightedTriggerScore: Codable, Equatable {
    struct Factor: Identifiable, Codable, Equatable {
        var id: String { name }
        var name: String
        var weight: Double
        var value: Double
        var contribution: Double
        var evidence: String
    }

    var calculatedAt = Date()
    var score: Double
    var tier: String
    var factors: [Factor]
    var topFactors: [Factor] {
        factors.sorted { $0.contribution > $1.contribution }.prefix(3).map { $0 }
    }
}

struct TinnitusSubtype: Codable, Equatable {
    enum Primary: String, Codable, CaseIterable {
        case tonal = "Tonal"
        case narrowbandNoise = "Narrowband Noise"
        case pulsatile = "Pulsatile"
        case complex = "Complex"
        case unknown = "Unknown"
    }
    
    enum Modifier: String, Codable, CaseIterable {
        case somatic = "Somatic"
        case reactive = "Reactive"
        case noiseInduced = "Noise-Induced"
        case stressModulated = "Stress-Modulated"
        case sleepModulated = "Sleep-Modulated"
    }
    
    enum Confidence: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    var primary: Primary
    var modifiers: Set<Modifier>
    var confidence: Confidence
    var pitchHz: Double?
    var evidence: [String]
}

