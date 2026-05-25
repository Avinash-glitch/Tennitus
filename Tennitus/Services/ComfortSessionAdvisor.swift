import Foundation

protocol ComfortSessionAdvisor {
    func suggestComfortSession(
        subtype: TinnitusSubtype,
        analysis: AudioAnalysisSummary,
        tinnitusMatchHz: Double,
        userDescription: String,
        backgroundDescription: String,
        triggerScore: WeightedTriggerScore?,
        healthContext: AppleHealthContext?
    ) async throws -> ComfortSessionSuggestion
}

enum ComfortSessionAdvisorError: LocalizedError {
    case invalidResponse(String)
    case requestFailed(String)
    case unconfigured(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Unexpected response: \(message)"
        case .requestFailed(let message):
            return message
        case .unconfigured(let message):
            return message
        }
    }
}
