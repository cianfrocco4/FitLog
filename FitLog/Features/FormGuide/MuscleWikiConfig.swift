//
//  MuscleWikiConfig.swift
//  FitLog
//
//  MuscleWiki form guide: proxy (FITLOG_FORM_GUIDE_BASE_URL) or direct API key.
//

import Foundation

enum MuscleWikiConfig {
    private static func trimmed(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Proxy base URL (option 1). From env FITLOG_FORM_GUIDE_BASE_URL or Info.plist.
    /// When set, the app calls your server; MUSCLEWIKI_API_KEY stays on the server.
    static var proxyBaseURL: String? {
        let resolved: String?
        if let env = ProcessInfo.processInfo.environment["FITLOG_FORM_GUIDE_BASE_URL"].flatMap(trimmed) {
            resolved = env
        } else {
            resolved = (Bundle.main.object(forInfoDictionaryKey: "FITLOG_FORM_GUIDE_BASE_URL") as? String).flatMap(trimmed)
        }
        #if DEBUG
        FitLogProxyEndpoints.warnIfStagingProxyConfigured(aiBaseURL: nil, formGuideBaseURL: resolved)
        #endif
        return resolved
    }

    /// Direct API key (dev fallback). Ignored when proxyBaseURL is set.
    static var apiKey: String? {
        guard proxyBaseURL == nil else { return nil }
        if let env = ProcessInfo.processInfo.environment["MUSCLEWIKI_API_KEY"].flatMap(trimmed) {
            return env
        }
        return (Bundle.main.object(forInfoDictionaryKey: "MUSCLEWIKI_API_KEY") as? String).flatMap(trimmed)
    }

    static let muscleWikiBaseURL = URL(string: "https://api.musclewiki.com")!

    static var usesProxy: Bool { proxyBaseURL != nil }

    static var isConfigured: Bool { proxyBaseURL != nil || apiKey != nil }

    /// Root URL for JSON API calls (search, exercises).
    static var apiRootURL: URL {
        if let base = proxyBaseURL, let url = URL(string: base) {
            return url.appending(path: "v1/form-guide")
        }
        return muscleWikiBaseURL
    }

    /// Base URL for branded exercise video streams (no trailing filename).
    static var streamBaseURL: URL {
        if let base = proxyBaseURL, let url = URL(string: base) {
            return url.appending(path: "v1/form-guide/stream/videos/branded")
        }
        return muscleWikiBaseURL.appending(path: "stream/videos/branded")
    }

    static let defaultSearchLimit = 1
    static let alternativeSearchLimit = 8

    static func searchURL(query: String, limit: Int = defaultSearchLimit) -> URL? {
        var components = URLComponents(url: apiRootURL.appending(path: "search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components?.url
    }

    static func exerciseURL(id: Int) -> URL {
        apiRootURL.appending(path: "exercises/\(id)")
    }

    static func streamURL(filename: String) -> URL {
        streamBaseURL.appending(path: filename)
    }
}
