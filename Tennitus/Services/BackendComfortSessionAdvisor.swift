import Foundation

struct BackendComfortSessionAdvisor: ComfortSessionAdvisor {
    let endpointURL: URL?
    
    init(endpointURL: URL? = BackendComfortSessionAdvisor.defaultEndpointURL()) {
        self.endpointURL = endpointURL
    }
    
    func suggestComfortSession(
        subtype: TinnitusSubtype,
        analysis: AudioAnalysisSummary,
        tinnitusMatchHz: Double,
        userDescription: String,
        backgroundDescription: String,
        triggerScore: WeightedTriggerScore?,
        healthContext: AppleHealthContext?
    ) async throws -> ComfortSessionSuggestion {
        guard let endpointURL else {
            throw ComfortSessionAdvisorError.unconfigured("AI proxy URL is not configured for this build.")
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = inputPayload(
            subtype: subtype,
            analysis: analysis,
            tinnitusMatchHz: tinnitusMatchHz,
            userDescription: userDescription,
            backgroundDescription: backgroundDescription,
            triggerScore: triggerScore,
            healthContext: healthContext
        )
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Backend API request failed."
            throw ComfortSessionAdvisorError.requestFailed("HTTP \(httpResponse.statusCode): \(message)")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ComfortSessionSuggestion.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8) ?? ""
            throw ComfortSessionAdvisorError.invalidResponse("Could not decode suggestion JSON: \(error.localizedDescription). Preview: \(preview.prefix(240))")
        }
    }
    
    private func inputPayload(
        subtype: TinnitusSubtype,
        analysis: AudioAnalysisSummary,
        tinnitusMatchHz: Double,
        userDescription: String,
        backgroundDescription: String,
        triggerScore: WeightedTriggerScore?,
        healthContext: AppleHealthContext?
    ) -> [String: Any] {
        let bandRows = analysis.bandEnergies.map {
            [
                "label": $0.label,
                "low_hz": Int($0.lowHz),
                "high_hz": Int($0.highHz),
                "energy_dbfs": rounded($0.energyDBFS),
                "relative_energy": rounded($0.relativeEnergy)
            ] as [String: Any]
        }
        
        var payload: [String: Any] = [
            "user_description": userDescription,
            "background_description": backgroundDescription,
            "tinnitus_match_hz": Int(tinnitusMatchHz),
            "duration_seconds": rounded(analysis.durationSeconds),
            "rms_dbfs": rounded(analysis.rmsDBFS),
            "peak_dbfs": rounded(analysis.peakDBFS),
            "spectral_centroid_hz": Int(analysis.spectralCentroidHz),
            "dominant_frequency_hz": Int(analysis.dominantFrequencyHz),
            "top_frequency_peaks_hz": analysis.topFrequencyPeaks.map { Int($0.frequencyHz.rounded()) },
            "target_sound_matches": analysis.targetSoundMatches.map { match in
                [
                    "label": match.label,
                    "time_range_seconds": [
                        "start": rounded(match.startSeconds),
                        "end": rounded(match.startSeconds + match.durationSeconds)
                    ],
                    "score_0_to_1": rounded(match.score),
                    "confidence": match.confidence,
                    "dominant_frequency_hz": Int(match.dominantFrequencyHz.rounded()),
                    "top_frequency_peaks_hz": match.topFrequencyPeaks.map { Int($0.frequencyHz.rounded()) },
                    "rationale": match.rationale
                ] as [String: Any]
            },
            "source_detections": analysis.sourceDetections.map { detection in
                [
                    "label": detection.label,
                    "confidence": rounded(detection.confidence),
                    "time_range_seconds": [
                        "start": rounded(detection.startSeconds),
                        "end": rounded(detection.startSeconds + detection.durationSeconds)
                    ],
                    "matched_user_description": detection.matchedUserDescription
                ] as [String: Any]
            },
            "dominant_band": analysis.dominantBandLabel,
            "high_frequency_ratio": rounded(analysis.highFrequencyRatio),
            "transient_count": analysis.transientCount,
            "sensitive_range_hz": [
                "low": Int(analysis.sensitiveRangeLowHz),
                "high": Int(analysis.sensitiveRangeHighHz)
            ],
            "band_energy": bandRows
        ]
        
        var profileObj: [String: Any] = [
            "primary": subtype.primary.rawValue,
            "modifiers": subtype.modifiers.map { $0.rawValue },
            "confidence": subtype.confidence.rawValue
        ]
        if let pitch = subtype.pitchHz {
            profileObj["pitch_hz"] = pitch
        }
        payload["pattern_profile"] = profileObj
        
        if let triggerScore {
            payload["weighted_trigger_score"] = [
                "score_0_to_1": rounded(triggerScore.score),
                "tier": triggerScore.tier,
                "factors": triggerScore.factors.map {
                    [
                        "name": $0.name,
                        "weight": rounded($0.weight),
                        "value_0_to_1": rounded($0.value),
                        "contribution": rounded($0.contribution),
                        "evidence": $0.evidence
                    ] as [String: Any]
                }
            ] as [String: Any]
        }
        
        if let healthContext {
            payload["apple_health_context"] = healthPayload(healthContext)
        }
        
        return payload
    }
    
    private func healthPayload(_ context: AppleHealthContext) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let sleep = context.sleep {
            payload["sleep"] = [
                "lookback_days": sleep.lookbackDays,
                "latest_night_asleep_hours": rounded(sleep.latestNightAsleepHours),
                "average_asleep_hours": rounded(sleep.averageAsleepHours)
            ]
        }
        if let hearing = context.hearing {
            var hearingPayload: [String: Any] = [
                "latest_audiogram_date": hearing.latestAudiogramDate?.ISO8601Format() ?? "",
                "source_name": hearing.sourceName ?? ""
            ]
            if let averageLeft = hearing.averageLeftDBHL {
                hearingPayload["average_left_db_hl"] = rounded(averageLeft)
            }
            if let averageRight = hearing.averageRightDBHL {
                hearingPayload["average_right_db_hl"] = rounded(averageRight)
            }
            payload["hearing"] = hearingPayload
        }
        return payload
    }
    
    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func defaultEndpointURL() -> URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "TENNITUS_AI_PROXY_URL") as? String,
           let url = URL(string: configured.trimmingCharacters(in: .whitespacesAndNewlines)),
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }

        #if DEBUG
        return URL(string: "http://127.0.0.1:8000/v1/comfort-session")
        #else
        return nil
        #endif
    }
}
