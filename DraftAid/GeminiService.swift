import Foundation

enum GeminiError: LocalizedError {
    case noAPIKey
    case httpError(Int, String?)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key set. Click the key icon to add your Google API key."
        case .httpError(let code, let message):
            if let message = message, !message.isEmpty {
                return "Gemini API error \(code): \(message)"
            }
            return "Gemini API returned HTTP \(code)."
        case .emptyReply:
            return "Gemini returned an empty response."
        }
    }
}

struct GenerationResult {
    let text: String
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct GeminiService {
    static let shared = GeminiService()

    static let modelDefaultsKey = "draftaid.model"
    static let defaultModel = "gemini-flash-latest"
    /// Used as a last resort when the selected model stays overloaded.
    static let fallbackModel = "gemini-3.6-flash"
    static let availableModels: [(id: String, label: String)] = [
        ("gemini-flash-latest", "Flash Latest - auto-updates to newest"),
        ("gemini-3.7-flash", "3.7 Flash - latest stable"),
        ("gemini-3.6-flash", "3.6 Flash - stable"),
        ("gemini-3.5-flash", "3.5 Flash - legacy stable"),
        ("gemini-3.5-flash-lite", "3.5 Flash-Lite - fastest, cheapest")
    ]

    private var model: String {
        UserDefaults.standard.string(forKey: GeminiService.modelDefaultsKey)
            ?? GeminiService.defaultModel
    }

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    private let keychainKey = "geminiAPIKey"
    private let maxAttempts = 3

    var hasAPIKey: Bool {
        guard let key = KeychainHelper.read(key: keychainKey) else { return false }
        return !key.isEmpty
    }

    /// Calls the API with automatic retry on temporary overload (503) and
    /// rate limiting (429), using exponential backoff (2s, 4s). If the
    /// selected model stays down, falls back once to `fallbackModel`.
    func generate(prompt: String) async throws -> GenerationResult {
        guard let apiKey = KeychainHelper.read(key: keychainKey), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        var attempt = 0
        while true {
            do {
                return try await performRequest(prompt: prompt, model: model, apiKey: apiKey)
            } catch GeminiError.httpError(let code, _) where code == 503 || code == 429 {
                attempt += 1
                if attempt >= maxAttempts {
                    // Last resort: one try on the stable fallback model
                    if model != GeminiService.fallbackModel,
                       let result = try? await performRequest(prompt: prompt, model: GeminiService.fallbackModel, apiKey: apiKey) {
                        return result
                    }
                    throw GeminiError.httpError(code, "Still unavailable after \(maxAttempts) attempts (fallback model also tried). Wait a minute and retry.")
                }
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }
    }

    /// Throws nil on success - used to verify a key before/after saving it.
    func validateKey(_ apiKey: String) async throws {
        _ = try await performRequest(prompt: "Reply with: OK", model: GeminiService.defaultModel, apiKey: apiKey)
    }

    private func performRequest(prompt: String, model: String, apiKey: String) async throws -> GenerationResult {
        guard let url = URL(string: "\(endpoint)/\(model):generateContent") else {
            throw GeminiError.emptyReply
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Key goes in the header, never in the URL (URLs get logged by proxies)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw GeminiError.httpError(status, message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.emptyReply
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiError.emptyReply }

        let usage = json["usageMetadata"] as? [String: Any]
        return GenerationResult(
            text: trimmed,
            promptTokens: usage?["promptTokenCount"] as? Int,
            completionTokens: usage?["candidatesTokenCount"] as? Int,
            totalTokens: usage?["totalTokenCount"] as? Int
        )
    }
}
