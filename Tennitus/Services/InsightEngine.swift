import Foundation

enum InsightEngine {
    static func generate(checkIns: [DailyCheckIn], spikes: [SpikeLog]) -> WeeklyInsight {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentCheckIns = checkIns.filter { $0.date >= start }
        let recentSpikes = spikes.filter { $0.startedAt >= start }

        guard !recentCheckIns.isEmpty else {
            return WeeklyInsight(
                checkInCount: 0,
                spikeCount: recentSpikes.count,
                averageLoudness: 0,
                averageDistress: 0,
                averageSleep: 0,
                averageStress: 0,
                confidence: "Low",
                headline: "Not enough check-ins yet",
                observations: ["Log at least 3 days this week to generate a useful summary."]
            )
        }

        let averageLoudness = average(recentCheckIns.map(\.loudness))
        let averageDistress = average(recentCheckIns.map(\.distress))
        let averageSleep = average(recentCheckIns.map(\.sleepQuality))
        let averageStress = average(recentCheckIns.map(\.stress))
        let confidence = confidenceLevel(totalCheckIns: checkIns.count, weeklyCheckIns: recentCheckIns.count)
        let headline = "This week averaged \(averageLoudness.formatted(.number.precision(.fractionLength(1)))) loudness and \(averageDistress.formatted(.number.precision(.fractionLength(1)))) distress."

        var observations = [
            "Based on \(recentCheckIns.count) check-ins and \(recentSpikes.count) spike logs from the last 7 days.",
            "Sleep averaged \(averageSleep.formatted(.number.precision(.fractionLength(1))))/10 and stress averaged \(averageStress.formatted(.number.precision(.fractionLength(1))))/10."
        ]

        if recentCheckIns.count < 3 {
            observations.append("Confidence is low because there are fewer than 3 check-ins this week.")
        }

        if averageStress >= 6 {
            observations.append("Higher stress often appeared alongside louder or more bothersome days. This is an association, not a cause.")
        }

        if recentSpikes.count > 0 {
            observations.append("Bring spike contexts and triggers to your appointment if they feel relevant.")
        }

        return WeeklyInsight(
            checkInCount: recentCheckIns.count,
            spikeCount: recentSpikes.count,
            averageLoudness: averageLoudness,
            averageDistress: averageDistress,
            averageSleep: averageSleep,
            averageStress: averageStress,
            confidence: confidence,
            headline: headline,
            observations: observations
        )
    }

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func confidenceLevel(totalCheckIns: Int, weeklyCheckIns: Int) -> String {
        if totalCheckIns >= 30 && weeklyCheckIns >= 5 { return "High" }
        if totalCheckIns >= 14 && weeklyCheckIns >= 3 { return "Medium" }
        return "Low"
    }
}
