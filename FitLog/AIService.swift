//
//  AIService.swift
//  FitLog
//
//  OpenAI Chat Completions for form tips and workout suggestions.
//

import Foundation

final class AIService: ObservableObject {
    private static let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    /// Model ID from OpenAIConfig.aiModel (configurable via FITLOG_AI_MODEL).
    private let model: String
    private let session: URLSession
    private var formTipsCache: [UUID: [String]] = [:]
    private var suggestionsCache: [String: [String]] = [:]
    private let cacheQueue = DispatchQueue(label: "FitLog.AIService.cache")

    /// When set, requests go to this base URL (option 1 proxy); key is not sent. Otherwise use OpenAI and apiKey.
    private let proxyBaseURL: String?
    private let apiKey: String?

    init(apiKey: String?, baseURL: String?, model: String? = nil) {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = (trimmedKey?.isEmpty ?? true) ? nil : trimmedKey
        let trimmedBase = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.proxyBaseURL = (trimmedBase?.isEmpty ?? true) ? nil : trimmedBase
        self.model = (model?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? OpenAIConfig.aiModel
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    var isConfigured: Bool {
        if proxyBaseURL != nil { return true }
        return apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    private var chatCompletionsURL: URL {
        if let base = proxyBaseURL, let url = URL(string: base)?.appending(path: "v1/chat/completions") {
            return url
        }
        return Self.openAIURL
    }
    
    // MARK: - Form tips (exercise)
    
    func fetchFormTips(for exercise: Exercise) async throws -> [String] {
        if !isConfigured {
            throw AIServiceError.notConfigured
        }
        let cached = cacheQueue.sync { formTipsCache[exercise.id] }
        if let cached = cached { return cached }
        
        let prompt = """
        For this strength exercise, give 3–5 short, actionable form tips or cues. One per line, no numbering or bullets. Be concise (one short sentence per tip).
        Exercise: \(exercise.name)
        Description: \(exercise.description)
        Target muscles: \(exercise.targetedMuscles.map(\.rawValue).joined(separator: ", "))
        """
        let content = try await performRequest(system: "You are a concise fitness coach. Reply only with form tips, one per line.", user: prompt, maxTokens: 300)
        let tips = content.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "•-–—")) }.filter { !$0.isEmpty }
        let result = tips.isEmpty ? [content] : tips
        cacheQueue.sync { formTipsCache[exercise.id] = result }
        return result
    }
    
    // MARK: - Workout suggestions
    /// Builds a short summary of the workout and asks for 2–4 improvement suggestions.
    func fetchWorkoutSuggestions(for workout: Workout) async throws -> [String] {
        if !isConfigured {
            throw AIServiceError.notConfigured
        }
        let key = workoutSummaryKey(workout)
        let cached = cacheQueue.sync { suggestionsCache[key] }
        if let cached = cached { return cached }
        
        let summary = workoutSummary(workout)
        let prompt = """
        Based on this workout plan, give 2–4 short, actionable suggestions to improve balance, volume, or structure. One per line, no numbering or bullets. Be concise.
        \(summary)
        """
        let content = try await performRequest(system: "You are a concise fitness coach. Reply only with suggestions, one per line.", user: prompt, maxTokens: 400)
        let suggestions = content.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "•-–—")) }.filter { !$0.isEmpty }
        let result = suggestions.isEmpty ? [content] : suggestions
        cacheQueue.sync { suggestionsCache[key] = result }
        return result
    }
    
    private func workoutSummaryKey(_ workout: Workout) -> String {
        let parts = workout.exercises.map { "\($0.exercise.name):\($0.recommendedSets)" }
        return parts.joined(separator: "|")
    }
    
    private func workoutSummary(_ workout: Workout) -> String {
        var lines: [String] = ["Workout: \(workout.name)"]
        for we in workout.exercises {
            let muscles = we.exercise.targetedMuscles.prefix(2).map(\.rawValue).joined(separator: ", ")
            lines.append("- \(we.exercise.name) (\(we.recommendedSets) sets x \(we.recommendedReps)) — \(muscles)")
        }
        return lines.joined(separator: "\n")
    }
    
    // MARK: - API
    private func performRequest(system: String, user: String, maxTokens: Int = 500) async throws -> String {
        let useProxy = proxyBaseURL != nil
        if !useProxy, (apiKey == nil || apiKey!.isEmpty) { throw AIServiceError.notConfigured }
        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        if !useProxy, let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let errorMessage = message?["message"] as? String ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AIServiceError.apiError(statusCode: http.statusCode, message: errorMessage)
        }
        let decoded = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else { throw AIServiceError.emptyContent }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors & API types
enum AIServiceError: LocalizedError {
    case notConfigured
    case invalidResponse
    case emptyContent
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenAI API key not set. Add OPENAI_API_KEY to your Xcode scheme or Info.plist."
        case .invalidResponse:
            return "Invalid response from server."
        case .emptyContent:
            return "Empty response from model."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}

private struct OpenAICompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable {
            let content: String?
        }
    }
}
