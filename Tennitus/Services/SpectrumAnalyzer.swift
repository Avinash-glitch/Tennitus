import Accelerate
import Foundation

enum SpectrumAnalyzer {
    private static let bands: [(label: String, low: Double, high: Double)] = [
        ("20-250 Hz", 20, 250),
        ("250-500 Hz", 250, 500),
        ("500 Hz-1 kHz", 500, 1_000),
        ("1-2 kHz", 1_000, 2_000),
        ("2-4 kHz", 2_000, 4_000),
        ("4-8 kHz", 4_000, 8_000),
        ("8-16 kHz", 8_000, 16_000)
    ]

    static func analyze(samples: [Float], sampleRate: Double) -> AudioAnalysisSummary {
        let cleaned = samples.filter { $0.isFinite }
        guard cleaned.count >= 512, sampleRate > 0 else {
            return emptySummary(sampleRate: sampleRate)
        }

        let fftSize = min(16_384, nearestLowerPowerOfTwo(cleaned.count))
        let windowed = Array(cleaned.suffix(fftSize))
        let powerSpectrum = makePowerSpectrum(samples: windowed)
        let binHz = sampleRate / Double(fftSize)

        let rawBandEnergies = bands.map { band in
            bandEnergy(label: band.label, lowHz: band.low, highHz: band.high, powerSpectrum: powerSpectrum, binHz: binHz)
        }
        let spectrumPoints = makeSpectrumPoints(powerSpectrum: powerSpectrum, binHz: binHz)
        let frequencyPeaks = detectFrequencyPeaks(powerSpectrum: powerSpectrum, binHz: binHz)

        let maxDB = rawBandEnergies.map(\.energyDBFS).max() ?? -120
        let minDB = rawBandEnergies.map(\.energyDBFS).min() ?? -120
        let spread = max(1, maxDB - minDB)
        let normalizedBands = rawBandEnergies.map { band in
            FrequencyBandEnergy(
                label: band.label,
                lowHz: band.lowHz,
                highHz: band.highHz,
                energyDBFS: band.energyDBFS,
                relativeEnergy: max(0, min(1, (band.energyDBFS - minDB) / spread))
            )
        }

        let dominant = normalizedBands.max { $0.energyDBFS < $1.energyDBFS }
        let peak = cleaned.map { abs($0) }.max() ?? 0
        let rms = sqrt(cleaned.reduce(Float(0)) { $0 + ($1 * $1) } / Float(cleaned.count))
        let highFrequencyEnergy = normalizedBands
            .filter { $0.lowHz >= 4_000 }
            .reduce(0) { $0 + pow(10, $1.energyDBFS / 10) }
        let totalEnergy = normalizedBands.reduce(0) { $0 + pow(10, $1.energyDBFS / 10) }

        return AudioAnalysisSummary(
            durationSeconds: Double(cleaned.count) / sampleRate,
            sampleRate: sampleRate,
            rmsDBFS: amplitudeToDBFS(rms),
            peakDBFS: amplitudeToDBFS(peak),
            spectralCentroidHz: spectralCentroid(powerSpectrum: powerSpectrum, binHz: binHz),
            dominantBandLabel: dominant?.label ?? "Unknown",
            highFrequencyRatio: totalEnergy > 0 ? highFrequencyEnergy / totalEnergy : 0,
            transientCount: estimateTransientCount(samples: cleaned, sampleRate: sampleRate),
            sensitiveRangeLowHz: dominant?.lowHz ?? 0,
            sensitiveRangeHighHz: dominant?.highHz ?? 0,
            bandEnergies: normalizedBands,
            spectrumPoints: spectrumPoints,
            dominantFrequencyHz: frequencyPeaks.first?.frequencyHz ?? spectralCentroid(powerSpectrum: powerSpectrum, binHz: binHz),
            topFrequencyPeaks: frequencyPeaks
        )
    }

    static func analyze(samples: [Float], sampleRate: Double, startSeconds: Double, endSeconds: Double) -> AudioAnalysisSummary {
        guard sampleRate > 0, endSeconds > startSeconds else {
            return analyze(samples: samples, sampleRate: sampleRate)
        }

        let lower = max(0, Int((startSeconds * sampleRate).rounded(.down)))
        let upper = min(samples.count, Int((endSeconds * sampleRate).rounded(.up)))
        guard lower < upper else {
            return analyze(samples: samples, sampleRate: sampleRate)
        }

        return analyze(samples: Array(samples[lower..<upper]), sampleRate: sampleRate)
    }

    static func analyzeTargeted(
        samples: [Float],
        sampleRate: Double,
        startSeconds: Double,
        endSeconds: Double,
        description: String
    ) -> AudioAnalysisSummary {
        let base = analyze(samples: samples, sampleRate: sampleRate, startSeconds: startSeconds, endSeconds: endSeconds)
        let matches = targetSoundMatches(
            samples: samples,
            sampleRate: sampleRate,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            description: description
        )
        return base.withTargetSoundMatches(matches)
    }

    static func stftSnapshots(
        samples: [Float],
        sampleRate: Double,
        windowSeconds: Double = 0.5,
        hopSeconds: Double = 0.5,
        startOffsetSeconds: Double = 0
    ) -> [SpectrumSnapshot] {
        guard !samples.isEmpty, sampleRate > 0, windowSeconds > 0, hopSeconds > 0 else { return [] }

        let windowSize = max(512, Int((windowSeconds * sampleRate).rounded()))
        let hopSize = max(1, Int((hopSeconds * sampleRate).rounded()))
        guard samples.count >= 512 else { return [] }

        var snapshots: [SpectrumSnapshot] = []
        var startIndex = 0
        while startIndex < samples.count {
            let endIndex = min(samples.count, startIndex + windowSize)
            guard endIndex - startIndex >= 512 else { break }
            let startSeconds = startOffsetSeconds + Double(startIndex) / sampleRate
            let analysis = analyze(samples: Array(samples[startIndex..<endIndex]), sampleRate: sampleRate)
            snapshots.append(SpectrumSnapshot(startSeconds: startSeconds, durationSeconds: Double(endIndex - startIndex) / sampleRate, analysis: analysis))
            startIndex += hopSize
        }

        return snapshots
    }

    static func targetSoundMatches(
        samples: [Float],
        sampleRate: Double,
        startSeconds: Double,
        endSeconds: Double,
        description: String
    ) -> [TargetSoundMatch] {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty, sampleRate > 0, endSeconds > startSeconds else { return [] }

        let profile = TargetSoundProfile.make(from: trimmedDescription)
        let lower = max(0, Int((startSeconds * sampleRate).rounded(.down)))
        let upper = min(samples.count, Int((endSeconds * sampleRate).rounded(.up)))
        guard upper - lower >= 512 else { return [] }

        let selectedSamples = Array(samples[lower..<upper])
        let snapshots = stftSnapshots(
            samples: selectedSamples,
            sampleRate: sampleRate,
            windowSeconds: 0.5,
            hopSeconds: 0.25,
            startOffsetSeconds: startSeconds
        )
        guard !snapshots.isEmpty else { return [] }

        return snapshots
            .map { snapshot in
                makeTargetSoundMatch(snapshot: snapshot, profile: profile, selectedStartSeconds: startSeconds)
            }
            .filter { $0.score >= 0.34 }
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { $0 }
    }

    static func localSuggestion(
        analysis: AudioAnalysisSummary,
        tinnitusMatchHz: Double,
        description: String
    ) -> ComfortSessionSuggestion {
        var rationale = [
            "Dominant recorded energy was in \(analysis.dominantBandLabel).",
            "Top detected frequency peaks were \(peakSummary(analysis.topFrequencyPeaks)).",
            "The user-matched tinnitus tone was \(Int(tinnitusMatchHz)) Hz.",
            "Overall recorded loudness was \(formatDB(analysis.rmsDBFS)) dBFS RMS and \(formatDB(analysis.peakDBFS)) dBFS peak."
        ]

        if analysis.highFrequencyRatio > 0.35 {
            rationale.append("High-frequency energy was elevated, so a softer high-frequency masking profile may be more comfortable.")
        }

        if analysis.transientCount >= 8 {
            rationale.append("Several transient peaks were detected, so avoid sharp/click-like masking sounds.")
        }

        if let match = analysis.targetSoundMatches.first {
            rationale.append("The described sound matched \(match.label) most around \(match.timeRangeLabel), with peaks \(peakSummary(match.topFrequencyPeaks)).")
        }

        let hasSpeechCue = description.lowercased().contains("voice") || description.lowercased().contains("speech") || description.lowercased().contains("sibil")
        if hasSpeechCue {
            rationale.append("The description mentions voice or sibilance, so the 4-8 kHz area may deserve attention.")
        }

        let targetRange = analysis.sensitiveRangeLabel
        let suggestedFrequency = max(100, min(12_000, tinnitusMatchHz))
        let suggestedSound = analysis.highFrequencyRatio > 0.35 ? "Pink noise with gentle high-frequency roll-off" : "Soft pink noise plus low-level matched tone"

        return ComfortSessionSuggestion(
            title: "Comfort session for \(targetRange)",
            summary: "Try a short, low-volume session that avoids emphasising the strongest uncomfortable band.",
            targetFrequencyRange: targetRange,
            suggestedSound: suggestedSound,
            suggestedFrequencyHz: suggestedFrequency,
            durationMinutes: 5,
            volumeGuidance: "Start barely audible and keep the sound below your tinnitus or discomfort level. Stop if it feels worse.",
            rationale: rationale,
            safetyNotes: [
                "This is a comfort experiment, not tinnitus treatment.",
                "Do not use painful or uncomfortable volume.",
                "Seek clinical advice for sudden hearing change, one-sided new symptoms, pulsatile tinnitus, vertigo, or severe distress."
            ],
            confidence: analysis.durationSeconds >= 5 ? "Medium" : "Low",
            disclaimer: "Not medical advice or a substitute for an audiologist."
        )
    }

    private static func makePowerSpectrum(samples: [Float]) -> [Double] {
        let count = samples.count
        let log2n = vDSP_Length(log2(Double(count)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }

        var window = [Float](repeating: 0, count: count)
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))

        var windowed = [Float](repeating: 0, count: count)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(count))

        var real = [Float](repeating: 0, count: count / 2)
        var imaginary = [Float](repeating: 0, count: count / 2)
        var magnitudes = [Float](repeating: 0, count: count / 2)

        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                windowed.withUnsafeBufferPointer { samplesBuffer in
                    samplesBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: count / 2) { complexBuffer in
                        vDSP_ctoz(complexBuffer, 2, &split, 1, vDSP_Length(count / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(count / 2))
            }
        }

        return magnitudes.map { Double(max($0, 1e-12)) }
    }

    private static func bandEnergy(label: String, lowHz: Double, highHz: Double, powerSpectrum: [Double], binHz: Double) -> FrequencyBandEnergy {
        guard !powerSpectrum.isEmpty, binHz > 0 else {
            return FrequencyBandEnergy(label: label, lowHz: lowHz, highHz: highHz, energyDBFS: -120, relativeEnergy: 0)
        }

        let lowerBin = max(1, Int(floor(lowHz / binHz)))
        let upperBin = min(powerSpectrum.count - 1, Int(ceil(highHz / binHz)))
        guard lowerBin <= upperBin else {
            return FrequencyBandEnergy(label: label, lowHz: lowHz, highHz: highHz, energyDBFS: -120, relativeEnergy: 0)
        }

        let slice = powerSpectrum[lowerBin...upperBin]
        let averagePower = slice.reduce(0, +) / Double(slice.count)
        let db = 10 * log10(max(averagePower, 1e-12))
        return FrequencyBandEnergy(label: label, lowHz: lowHz, highHz: highHz, energyDBFS: db, relativeEnergy: 0)
    }

    private static func makeSpectrumPoints(powerSpectrum: [Double], binHz: Double) -> [FrequencySpectrumPoint] {
        guard !powerSpectrum.isEmpty, binHz > 0 else { return [] }

        let minHz = 60.0
        let maxHz = min(16_000.0, Double(powerSpectrum.count - 1) * binHz)
        guard maxHz > minHz else { return [] }

        let pointCount = 96
        let minLog = log10(minHz)
        let maxLog = log10(maxHz)
        var points: [(frequency: Double, db: Double)] = []
        points.reserveCapacity(pointCount)

        for index in 0..<pointCount {
            let ratio = Double(index) / Double(pointCount - 1)
            let frequency = pow(10, minLog + ratio * (maxLog - minLog))
            let bin = max(1, min(powerSpectrum.count - 1, Int((frequency / binHz).rounded())))
            let lower = max(1, bin - 1)
            let upper = min(powerSpectrum.count - 1, bin + 1)
            let averagePower = powerSpectrum[lower...upper].reduce(0, +) / Double(upper - lower + 1)
            points.append((frequency, 10 * log10(max(averagePower, 1e-12))))
        }

        let minDB = points.map(\.db).min() ?? -120
        let maxDB = points.map(\.db).max() ?? -120
        let spread = max(1, maxDB - minDB)

        return points.map { point in
            FrequencySpectrumPoint(
                frequencyHz: point.frequency,
                magnitudeDB: point.db,
                normalizedMagnitude: max(0, min(1, (point.db - minDB) / spread))
            )
        }
    }

    private static func detectFrequencyPeaks(powerSpectrum: [Double], binHz: Double) -> [FrequencyPeak] {
        guard powerSpectrum.count > 8, binHz > 0 else { return [] }

        let minFrequency = 60.0
        let maxFrequency = min(16_000.0, Double(powerSpectrum.count - 1) * binHz)
        let lowerBin = max(2, Int((minFrequency / binHz).rounded(.up)))
        let upperBin = min(powerSpectrum.count - 3, Int((maxFrequency / binHz).rounded(.down)))
        guard lowerBin < upperBin else { return [] }

        let maxPower = powerSpectrum[lowerBin...upperBin].max() ?? 1e-12
        let floorPower = maxPower * 0.000_1
        var candidates: [(frequency: Double, db: Double, power: Double)] = []

        for bin in lowerBin...upperBin {
            let power = powerSpectrum[bin]
            guard power >= floorPower else { continue }
            guard power > powerSpectrum[bin - 1], power >= powerSpectrum[bin + 1] else { continue }

            let localStart = max(lowerBin, bin - 2)
            let localEnd = min(upperBin, bin + 2)
            let localPower = powerSpectrum[localStart...localEnd].reduce(0, +) / Double(localEnd - localStart + 1)
            candidates.append((Double(bin) * binHz, 10 * log10(max(localPower, 1e-12)), localPower))
        }

        let separated = candidates
            .sorted { $0.power > $1.power }
            .reduce(into: [(frequency: Double, db: Double, power: Double)]()) { result, candidate in
                let tooClose = result.contains { existing in
                    abs(log2(max(candidate.frequency, 1) / max(existing.frequency, 1))) < 1.0 / 18.0
                }
                if !tooClose {
                    result.append(candidate)
                }
            }
            .prefix(5)

        let selected = Array(separated)
        let minDB = selected.map(\.db).min() ?? -120
        let maxDB = selected.map(\.db).max() ?? -120
        let spread = max(1, maxDB - minDB)

        return selected.map {
            FrequencyPeak(
                frequencyHz: $0.frequency,
                magnitudeDB: $0.db,
                normalizedMagnitude: max(0, min(1, ($0.db - minDB) / spread))
            )
        }
    }

    private static func spectralCentroid(powerSpectrum: [Double], binHz: Double) -> Double {
        guard !powerSpectrum.isEmpty else { return 0 }
        var weighted = 0.0
        var total = 0.0
        for (index, power) in powerSpectrum.enumerated() {
            let frequency = Double(index) * binHz
            weighted += frequency * power
            total += power
        }
        return total > 0 ? weighted / total : 0
    }

    private static func estimateTransientCount(samples: [Float], sampleRate: Double) -> Int {
        let windowSize = max(128, Int(sampleRate / 100))
        guard samples.count > windowSize * 2 else { return 0 }

        var count = 0
        var previousRMS: Float = 0
        var index = 0
        while index + windowSize < samples.count {
            let chunk = samples[index..<(index + windowSize)]
            let rms = sqrt(chunk.reduce(Float(0)) { $0 + ($1 * $1) } / Float(windowSize))
            if previousRMS > 0, rms > previousRMS * 1.9, amplitudeToDBFS(rms) > -45 {
                count += 1
            }
            previousRMS = max(previousRMS * 0.85, rms)
            index += windowSize
        }
        return count
    }

    private static func nearestLowerPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power * 2 <= value {
            power *= 2
        }
        return max(512, power)
    }

    private static func amplitudeToDBFS(_ value: Float) -> Double {
        20 * log10(Double(max(value, 0.000_001)))
    }

    private static func formatDB(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private static func peakSummary(_ peaks: [FrequencyPeak]) -> String {
        guard !peaks.isEmpty else { return "not available" }
        return peaks.prefix(3).map { formatHz($0.frequencyHz) }.joined(separator: ", ")
    }

    private static func formatHz(_ hz: Double) -> String {
        hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz.rounded())) Hz"
    }

    private static func emptySummary(sampleRate: Double) -> AudioAnalysisSummary {
        AudioAnalysisSummary(
            durationSeconds: 0,
            sampleRate: sampleRate,
            rmsDBFS: -120,
            peakDBFS: -120,
            spectralCentroidHz: 0,
            dominantBandLabel: "Unknown",
            highFrequencyRatio: 0,
            transientCount: 0,
            sensitiveRangeLowHz: 0,
            sensitiveRangeHighHz: 0,
            bandEnergies: bands.map {
                FrequencyBandEnergy(label: $0.label, lowHz: $0.low, highHz: $0.high, energyDBFS: -120, relativeEnergy: 0)
            },
            spectrumPoints: [],
            dominantFrequencyHz: 0,
            topFrequencyPeaks: []
        )
    }

    private static func makeTargetSoundMatch(
        snapshot: SpectrumSnapshot,
        profile: TargetSoundProfile,
        selectedStartSeconds: Double
    ) -> TargetSoundMatch {
        let analysis = snapshot.analysis
        let bandScore = targetEnergyRatio(analysis: analysis, ranges: profile.energyRanges)
        let peakScore = targetPeakScore(peaks: analysis.topFrequencyPeaks, ranges: profile.peakRanges)
        let centroidScore = score(value: analysis.spectralCentroidHz, target: profile.centroidHz, tolerance: profile.centroidToleranceHz)
        let transientScore = min(1.0, Double(analysis.transientCount) / Double(max(1, profile.transientCountForFullScore)))
        let loudnessScore = score(value: analysis.rmsDBFS, target: -32, tolerance: 22)
        let highRatioScore = score(value: analysis.highFrequencyRatio, target: profile.highFrequencyRatio, tolerance: 0.32)
        let total = (
            bandScore * 0.32 +
            peakScore * 0.25 +
            centroidScore * 0.16 +
            transientScore * profile.transientWeight +
            loudnessScore * 0.12 +
            highRatioScore * 0.08
        )

        var rationale = [
            "Band energy matched \(profile.label) profile: \(percent(bandScore)).",
            "Peak match in target ranges: \(percent(peakScore)).",
            "Window centroid \(formatHz(analysis.spectralCentroidHz))."
        ]

        if analysis.transientCount > 0 {
            rationale.append("Transient count in this window: \(analysis.transientCount).")
        }

        return TargetSoundMatch(
            label: profile.label,
            startSeconds: selectedStartSeconds + snapshot.startSeconds,
            durationSeconds: snapshot.durationSeconds,
            score: max(0, min(1, total)),
            confidence: confidence(for: total),
            dominantFrequencyHz: analysis.dominantFrequencyHz,
            topFrequencyPeaks: analysis.topFrequencyPeaks,
            rationale: rationale
        )
    }

    private static func targetEnergyRatio(analysis: AudioAnalysisSummary, ranges: [ClosedRange<Double>]) -> Double {
        let total = analysis.bandEnergies.reduce(0.0) { $0 + dbToPower($1.energyDBFS) }
        guard total > 0 else { return 0 }

        let target = analysis.bandEnergies
            .filter { band in
                ranges.contains { bandsOverlap($0, band.lowHz...band.highHz) }
            }
            .reduce(0.0) { $0 + dbToPower($1.energyDBFS) }

        return max(0, min(1, target / total))
    }

    private static func targetPeakScore(peaks: [FrequencyPeak], ranges: [ClosedRange<Double>]) -> Double {
        guard !peaks.isEmpty else { return 0 }
        let weighted = peaks.reduce(0.0) { partial, peak in
            let inRange = ranges.contains { $0.contains(peak.frequencyHz) }
            return partial + (inRange ? max(0.25, peak.normalizedMagnitude) : 0)
        }
        return max(0, min(1, weighted / min(3.0, Double(peaks.count))))
    }

    private static func score(value: Double, target: Double, tolerance: Double) -> Double {
        guard value.isFinite, target.isFinite, tolerance > 0 else { return 0 }
        return max(0, min(1, 1 - abs(value - target) / tolerance))
    }

    private static func bandsOverlap(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }

    private static func dbToPower(_ db: Double) -> Double {
        pow(10, db / 10)
    }

    private static func confidence(for score: Double) -> String {
        switch score {
        case 0.72...:
            return "High"
        case 0.50..<0.72:
            return "Medium"
        default:
            return "Low"
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((max(0, min(1, value)) * 100).rounded()))%"
    }
}

private struct TargetSoundProfile {
    var label: String
    var energyRanges: [ClosedRange<Double>]
    var peakRanges: [ClosedRange<Double>]
    var centroidHz: Double
    var centroidToleranceHz: Double
    var highFrequencyRatio: Double
    var transientCountForFullScore: Int
    var transientWeight: Double

    static func make(from description: String) -> TargetSoundProfile {
        let normalized = description.lowercased()

        if normalized.contains("electric guitar") || normalized.contains("guitar") {
            return TargetSoundProfile(
                label: "electric guitar-like sound",
                energyRanges: [80...1_200, 1_500...5_000, 5_000...8_000],
                peakRanges: [80...1_500, 1_500...5_500],
                centroidHz: 2_200,
                centroidToleranceHz: 2_600,
                highFrequencyRatio: 0.24,
                transientCountForFullScore: 4,
                transientWeight: 0.07
            )
        }

        if normalized.contains("voice") || normalized.contains("speech") || normalized.contains("vocal") || normalized.contains("sibil") {
            return TargetSoundProfile(
                label: "voice/sibilance-like sound",
                energyRanges: [250...4_000, 4_000...8_000],
                peakRanges: [120...4_000, 4_000...9_000],
                centroidHz: 2_500,
                centroidToleranceHz: 3_000,
                highFrequencyRatio: 0.30,
                transientCountForFullScore: 3,
                transientWeight: 0.06
            )
        }

        if normalized.contains("cymbal") || normalized.contains("hiss") || normalized.contains("sharp") || normalized.contains("screech") {
            return TargetSoundProfile(
                label: "sharp high-frequency sound",
                energyRanges: [4_000...16_000],
                peakRanges: [3_000...16_000],
                centroidHz: 7_000,
                centroidToleranceHz: 5_000,
                highFrequencyRatio: 0.55,
                transientCountForFullScore: 5,
                transientWeight: 0.10
            )
        }

        if normalized.contains("bass") || normalized.contains("rumble") || normalized.contains("engine") {
            return TargetSoundProfile(
                label: "low-frequency sound",
                energyRanges: [20...500],
                peakRanges: [40...700],
                centroidHz: 250,
                centroidToleranceHz: 650,
                highFrequencyRatio: 0.08,
                transientCountForFullScore: 2,
                transientWeight: 0.04
            )
        }

        if normalized.contains("beep") || normalized.contains("alarm") || normalized.contains("tone") || normalized.contains("whistle") {
            return TargetSoundProfile(
                label: "tonal alarm-like sound",
                energyRanges: [500...8_000],
                peakRanges: [500...10_000],
                centroidHz: 2_500,
                centroidToleranceHz: 3_500,
                highFrequencyRatio: 0.35,
                transientCountForFullScore: 2,
                transientWeight: 0.03
            )
        }

        return TargetSoundProfile(
            label: "described sound",
            energyRanges: [250...8_000],
            peakRanges: [120...10_000],
            centroidHz: 2_000,
            centroidToleranceHz: 4_000,
            highFrequencyRatio: 0.25,
            transientCountForFullScore: 3,
            transientWeight: 0.06
        )
    }
}
