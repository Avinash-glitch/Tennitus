import Foundation

struct TennitusPortableExport: Codable {
    struct Recording: Codable {
        var eventID: UUID
        var fileName: String
        var originalPath: String
        var mimeType: String
        var base64Audio: String
        var selectedStartSeconds: Double
        var selectedEndSeconds: Double
        var tinnitusMatchFrequencyHz: Double
        var dominantBandLabel: String
        var sensitiveRangeLowHz: Double
        var sensitiveRangeHighHz: Double
        var peakDBFS: Double
        var rmsDBFS: Double
        var userDescription: String
        var backgroundDescription: String
    }

    var schemaName = "com.avinashkannan.tennitus.portable-export"
    var schemaVersion = 1
    var exportedAt = Date()
    var appBuild = "ios-native-mvp"
    var profile: TinnitusProfile
    var checkIns: [DailyCheckIn]
    var spikes: [SpikeLog]
    var audioEvents: [AudioEventLog]
    var latestAudiogram: AudiogramScreeningResult
    var aiResponses: [AIResponseLog]
    var appleHealthContext: AppleHealthContext
    var recordings: [Recording]
}

enum PortableDataExportService {
    static func generate(store: AppStore, includeAudio: Bool = true) throws -> URL {
        let recordings = includeAudio ? makeRecordingExports(from: store.audioEvents) : []
        let export = TennitusPortableExport(
            profile: store.profile,
            checkIns: store.checkIns,
            spikes: store.spikes,
            audioEvents: store.audioEvents,
            latestAudiogram: store.latestAudiogram,
            aiResponses: store.aiResponses,
            appleHealthContext: store.appleHealthContext,
            recordings: recordings
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(export)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TennitusExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("tennitus-portable-export-\(stamp).json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private static func makeRecordingExports(from events: [AudioEventLog]) -> [TennitusPortableExport.Recording] {
        events.compactMap { event in
            guard let path = event.audioFilePath else { return nil }
            let url = URL(fileURLWithPath: path)
            guard let data = try? Data(contentsOf: url) else { return nil }

            return TennitusPortableExport.Recording(
                eventID: event.id,
                fileName: url.lastPathComponent,
                originalPath: path,
                mimeType: "audio/x-caf",
                base64Audio: data.base64EncodedString(),
                selectedStartSeconds: event.selectedStartSeconds,
                selectedEndSeconds: event.selectedEndSeconds,
                tinnitusMatchFrequencyHz: event.tinnitusMatchFrequencyHz,
                dominantBandLabel: event.analysis.dominantBandLabel,
                sensitiveRangeLowHz: event.analysis.sensitiveRangeLowHz,
                sensitiveRangeHighHz: event.analysis.sensitiveRangeHighHz,
                peakDBFS: event.analysis.peakDBFS,
                rmsDBFS: event.analysis.rmsDBFS,
                userDescription: event.userDescription,
                backgroundDescription: event.backgroundDescription
            )
        }
    }
}
