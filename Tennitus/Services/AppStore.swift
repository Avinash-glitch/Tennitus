import Combine
import Foundation

final class AppStore: ObservableObject {
    private let storageKey = "tennitus.local.store.v2"
    let comfortAdvisor: ComfortSessionAdvisor = BackendComfortSessionAdvisor()

    @Published var profile = TinnitusProfile() {
        didSet { persist() }
    }

    @Published var checkIns: [DailyCheckIn] = [] {
        didSet { persist() }
    }

    @Published var spikes: [SpikeLog] = [] {
        didSet { persist() }
    }

    @Published var audioEvents: [AudioEventLog] = [] {
        didSet { persist() }
    }

    @Published var latestAudiogram = AudiogramScreeningResult.empty {
        didSet { persist() }
    }

    @Published var aiResponses: [AIResponseLog] = [] {
        didSet { persist() }
    }

    @Published var appleHealthContext = AppleHealthContext.empty {
        didSet { persist() }
    }

    init() {
        load()
        if checkIns.isEmpty {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "tennitus.seedDemoData") {
                seedDemoData()
            }
            #endif
        }
    }

    var latestCheckIn: DailyCheckIn? {
        checkIns.sorted { $0.date > $1.date }.first
    }

    var detectedSubtype: TinnitusSubtype {
        TinnitusSubtypeClassifier.classify(profile: profile, checkIns: checkIns, spikes: spikes)
    }

    var weeklyInsight: WeeklyInsight {
        InsightEngine.generate(checkIns: checkIns, spikes: spikes)
    }

    func save(_ checkIn: DailyCheckIn) {
        if let index = checkIns.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: checkIn.date) }) {
            checkIns[index] = checkIn
        } else {
            checkIns.append(checkIn)
        }
    }

    func save(_ spike: SpikeLog) {
        spikes.append(spike)
    }

    func save(_ event: AudioEventLog) {
        audioEvents.insert(event, at: 0)
    }

    func update(_ event: AudioEventLog) {
        guard let index = audioEvents.firstIndex(where: { $0.id == event.id }) else {
            save(event)
            return
        }
        audioEvents[index] = event
    }

    func save(_ audiogram: AudiogramScreeningResult) {
        latestAudiogram = audiogram
    }

    func save(_ response: AIResponseLog) {
        aiResponses.insert(response, at: 0)
    }

    func save(_ context: AppleHealthContext) {
        appleHealthContext = context
    }

    func deleteAllData() {
        profile = TinnitusProfile()
        checkIns = []
        spikes = []
        audioEvents = []
        latestAudiogram = .empty
        aiResponses = []
        appleHealthContext = .empty
    }

    private func seedDemoData() {
        let calendar = Calendar.current
        checkIns = (0..<8).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return DailyCheckIn(
                date: date,
                loudness: [4, 5, 6, 4, 3, 5, 7, 4][offset],
                distress: [3, 5, 6, 4, 3, 4, 7, 4][offset],
                sleepQuality: [7, 5, 4, 6, 7, 5, 3, 6][offset],
                stress: [3, 5, 7, 4, 3, 6, 8, 4][offset],
                mood: [7, 6, 5, 6, 7, 5, 4, 6][offset],
                headphoneUse: offset == 2 ? .threePlusHours : .underOneHour,
                noiseExposure: offset == 6 ? .loud : .moderate,
                notes: ""
            )
        }
        spikes = [
            SpikeLog(loudness: 8, distress: 7, context: "Commute", triggers: [.noise, .stress], notes: "Busy train after poor sleep")
        ]
        persist()
    }

    private func persist() {
        let snapshot = StoreSnapshot(
            profile: profile,
            checkIns: checkIns,
            spikes: spikes,
            audioEvents: audioEvents,
            latestAudiogram: latestAudiogram,
            aiResponses: aiResponses,
            appleHealthContext: appleHealthContext
        )
        guard let data = try? JSONEncoder.tennitus.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let snapshot = try? JSONDecoder.tennitus.decode(StoreSnapshot.self, from: data)
        else { return }

        profile = snapshot.profile
        checkIns = snapshot.checkIns
        spikes = snapshot.spikes
        audioEvents = snapshot.audioEvents
        latestAudiogram = snapshot.latestAudiogram
        aiResponses = snapshot.aiResponses
        appleHealthContext = snapshot.appleHealthContext
    }
}

private struct StoreSnapshot: Codable {
    var profile: TinnitusProfile
    var checkIns: [DailyCheckIn]
    var spikes: [SpikeLog]
    var audioEvents: [AudioEventLog]
    var latestAudiogram: AudiogramScreeningResult
    var aiResponses: [AIResponseLog]
    var appleHealthContext: AppleHealthContext

    init(
        profile: TinnitusProfile,
        checkIns: [DailyCheckIn],
        spikes: [SpikeLog],
        audioEvents: [AudioEventLog],
        latestAudiogram: AudiogramScreeningResult,
        aiResponses: [AIResponseLog],
        appleHealthContext: AppleHealthContext
    ) {
        self.profile = profile
        self.checkIns = checkIns
        self.spikes = spikes
        self.audioEvents = audioEvents
        self.latestAudiogram = latestAudiogram
        self.aiResponses = aiResponses
        self.appleHealthContext = appleHealthContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(TinnitusProfile.self, forKey: .profile)
        checkIns = try container.decode([DailyCheckIn].self, forKey: .checkIns)
        spikes = try container.decode([SpikeLog].self, forKey: .spikes)
        audioEvents = try container.decode([AudioEventLog].self, forKey: .audioEvents)
        latestAudiogram = try container.decode(AudiogramScreeningResult.self, forKey: .latestAudiogram)
        aiResponses = try container.decodeIfPresent([AIResponseLog].self, forKey: .aiResponses) ?? []
        appleHealthContext = try container.decodeIfPresent(AppleHealthContext.self, forKey: .appleHealthContext) ?? .empty
    }
}

private extension JSONEncoder {
    static var tennitus: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var tennitus: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
