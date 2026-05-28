//
//  OpenAIConfig.swift
//  FitLog
//
//  Option 1 (backend proxy): Set FITLOG_AI_BASE_URL → app calls your server; key stays on server.
//  Option 3 (key in app): Set OPENAI_API_KEY → app calls OpenAI directly.
//

import Foundation

enum OpenAIConfig {
    private static func trimmed(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// API key for direct OpenAI calls (option 3). Ignored when using a proxy (option 1).
    static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"].flatMap(trimmed) {
            return env
        }
        return (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String).flatMap(trimmed)
    }

    /// Base URL of your AI proxy (option 1), e.g. "https://your-app.up.railway.app". No trailing slash.
    /// From env FITLOG_AI_BASE_URL or Info.plist key FITLOG_AI_BASE_URL.
    static var aiBaseURL: String? {
        let resolved: String?
        if let env = ProcessInfo.processInfo.environment["FITLOG_AI_BASE_URL"].flatMap(trimmed) {
            resolved = env
        } else {
            resolved = (Bundle.main.object(forInfoDictionaryKey: "FITLOG_AI_BASE_URL") as? String).flatMap(trimmed)
        }
        #if DEBUG
        FitLogProxyEndpoints.warnIfStagingProxyConfigured(aiBaseURL: resolved, formGuideBaseURL: nil)
        #endif
        return resolved
    }

    /// Model ID for Chat Completions (e.g. "gpt-4o-mini", "gpt-5-mini").
    /// From env FITLOG_AI_MODEL or Info.plist FITLOG_AI_MODEL. Default: gpt-4o-mini.
    static var aiModel: String {
        if let env = ProcessInfo.processInfo.environment["FITLOG_AI_MODEL"].flatMap(trimmed) {
            return env
        }
        if let plist = (Bundle.main.object(forInfoDictionaryKey: "FITLOG_AI_MODEL") as? String).flatMap(trimmed) {
            return plist
        }
        return "gpt-4o-mini"
    }

    /// True if either proxy base URL or API key is set.
    static var isConfigured: Bool { aiBaseURL != nil || apiKey != nil }
}
