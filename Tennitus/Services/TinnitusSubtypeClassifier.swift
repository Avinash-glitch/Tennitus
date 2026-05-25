import Foundation

enum TinnitusSubtypeClassifier {
    static func classify(
        profile: TinnitusProfile,
        checkIns: [DailyCheckIn],
        spikes: [SpikeLog]
    ) -> TinnitusSubtype {
        if profile.redFlags?.hasRedFlags == true {
            return TinnitusSubtype(
                primary: .unknown,
                modifiers: [],
                confidence: .low,
                pitchHz: nil,
                evidence: ["Medical review recommended. You have reported symptoms (such as sudden changes, pain, dizziness, or pulsatile sounds) that require evaluation by a healthcare professional. We will not provide pattern analysis while red flags are active."]
            )
        }

        var primary: TinnitusSubtype.Primary = .unknown
        var modifiers: Set<TinnitusSubtype.Modifier> = []
        var evidence: [String] = []
        
        // 1. Determine Primary Type based on SoundType
        switch profile.soundType {
        case .ringing:
            primary = .tonal
            evidence.append("Primary type set to Tonal because your sound profile is described as Ringing.")
        case .hissing, .buzzing:
            primary = .narrowbandNoise
            evidence.append("Primary type set to Narrowband Noise because your sound is described as \(profile.soundType.rawValue.lowercased()).")
        case .whooshing, .pulsing:
            primary = .pulsatile
            evidence.append("Primary type set to Pulsatile because your sound is described as \(profile.soundType.rawValue.lowercased()). Note: Pulsatile symptoms should be discussed with a medical professional.")
        case .multiple:
            primary = .complex
            evidence.append("Primary type set to Complex because you reported experiencing multiple types of sounds.")
        case .other:
            primary = .unknown
            evidence.append("Primary type is currently Unknown (listed as Other).")
        }
        
        // 2. Extract Pitch
        var pitchHz: Double? = nil
        if primary == .tonal || primary == .complex {
            if let savedTone = profile.savedToneFrequencyHz {
                pitchHz = savedTone
                let frequencyString = savedTone >= 1000 ? String(format: "%.1f kHz", savedTone / 1000.0) : "\(Int(savedTone)) Hz"
                evidence.append("Matched frequency pitch identified at \(frequencyString).")
            }
        }
        
        // 3. Somatic Modifier (Jaw / Neck modulation)
        let jawNeckSpikesCount = spikes.filter { $0.triggers.contains(.jawNeck) }.count
        if jawNeckSpikesCount > 0 {
            modifiers.insert(.somatic)
            evidence.append("Somatic modulation modifier active: You reported jaw or neck movements triggering your spikes \(jawNeckSpikesCount) time(s).")
        }
        
        // 4. Reactive Modifier (External sound triggered)
        let soundTriggeredSpikes = spikes.filter { $0.triggers.contains(.noise) || $0.triggers.contains(.headphones) }.count
        if soundTriggeredSpikes >= 2 {
            modifiers.insert(.reactive)
            evidence.append("Reactive modifier active: You reported external noise or headphone use triggering spikes \(soundTriggeredSpikes) times.")
        }
        
        // 5. Noise-Induced Modifier
        let hasLoudExposureCheckin = checkIns.contains { $0.noiseExposure == .loud || $0.noiseExposure == .veryLoud }
        if hasLoudExposureCheckin {
            modifiers.insert(.noiseInduced)
            evidence.append("Noise-Induced modifier active: Your check-in history records periods of loud or very loud noise exposure.")
        }
        
        // 6. Stress-Modulated Modifier
        let averageStress = checkIns.isEmpty ? 0.0 : Double(checkIns.map(\.stress).reduce(0, +)) / Double(checkIns.count)
        let stressSpikeCount = spikes.filter { $0.triggers.contains(.stress) }.count
        if averageStress >= 5.5 || stressSpikeCount >= 1 {
            modifiers.insert(.stressModulated)
            let stressDetail = averageStress >= 5.5 ? String(format: "average stress is %.1f/10", averageStress) : "stress triggers logged in spikes"
            evidence.append("Stress-Modulated modifier active: Your profiles show stress impacts (\(stressDetail)).")
        }
        
        // 7. Sleep-Modulated Modifier
        let averageSleepQuality = checkIns.isEmpty ? 10.0 : Double(checkIns.map(\.sleepQuality).reduce(0, +)) / Double(checkIns.count)
        let poorSleepSpikeCount = spikes.filter { $0.triggers.contains(.poorSleep) }.count
        if averageSleepQuality <= 5.0 || poorSleepSpikeCount >= 1 {
            modifiers.insert(.sleepModulated)
            let sleepDetail = averageSleepQuality <= 5.0 ? String(format: "average sleep quality is %.1f/10", averageSleepQuality) : "poor sleep triggers logged in spikes"
            evidence.append("Sleep-Modulated modifier active: Sleep disruptions detected (\(sleepDetail)).")
        }
        
        // 8. Confidence Score Determination
        var confidence: TinnitusSubtype.Confidence = .low
        let sampleCount = checkIns.count + spikes.count
        
        if primary != .unknown {
            if sampleCount >= 5 || (pitchHz != nil && sampleCount >= 2) {
                confidence = .high
            } else {
                confidence = .medium
            }
        } else {
            confidence = .low
        }
        
        return TinnitusSubtype(
            primary: primary,
            modifiers: modifiers,
            confidence: confidence,
            pitchHz: pitchHz,
            evidence: evidence
        )
    }
}
