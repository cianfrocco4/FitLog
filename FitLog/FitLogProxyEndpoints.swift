//
//  FitLogProxyEndpoints.swift
//  FitLog
//
//  Canonical production proxy host for AI chat and form guide (Render).
//

import Foundation

enum FitLogProxyEndpoints {
    /// Production Render web service (not the separate Testing service).
    static let productionBaseURL = "https://the-workout-log.onrender.com"

    static func isStagingHost(_ urlString: String?) -> Bool {
        guard let raw = urlString?.lowercased() else { return false }
        return raw.contains("the-workout-log-testing.onrender.com")
    }

    #if DEBUG
    /// Logs when scheme env or plist still points at the Render Testing service.
    static func warnIfStagingProxyConfigured(aiBaseURL: String?, formGuideBaseURL: String?) {
        if isStagingHost(aiBaseURL) || isStagingHost(formGuideBaseURL) {
            print(
                "[FitLog] Proxy URL points at Render Testing. For production-like runs use \(productionBaseURL) in Info.plist or clear scheme overrides."
            )
        }
    }
    #endif
}
