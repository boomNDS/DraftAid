import Foundation
import FoundationModels

/// Which AI engine processes text. Apple is the default: free, private,
/// works offline, zero setup. Gemini is the opt-in cloud upgrade.
enum AIEngine: String, CaseIterable {
    case apple
    case gemini

    static let defaultsKey = "draftaid.engine"

    var label: String {
        switch self {
        case .apple: return "On-Device (Apple) - free, private, no setup"
        case .gemini: return "Cloud (Gemini) - best quality, needs API key"
        }
    }
}

enum LocalModelError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        }
    }
}

struct LocalModelService {
    static let shared = LocalModelService()

    private var systemModel: SystemLanguageModel { SystemLanguageModel.default }

    var isAvailable: Bool {
        if case .available = systemModel.availability { return true }
        return false
    }

    var availabilityMessage: String? {
        switch systemModel.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off. Enable it in System Settings → Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again in a few minutes."
        case .unavailable:
            return "The on-device model is unavailable."
        }
    }

    /// Runs the prompt on Apple's local model. No tokens are reported by the
    /// framework, so token fields are nil (history just omits them).
    func generate(prompt: String) async throws -> GenerationResult {
        if let message = availabilityMessage {
            throw LocalModelError.unavailable(message)
        }

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiError.emptyReply }

        return GenerationResult(
            text: text,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil
        )
    }
}
