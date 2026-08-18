//
//  FitLogProxyConfig.swift
//  FitLog
//
//  Shared secret for authenticated backend proxy requests.
//

import Foundation

enum FitLogProxyConfig {
    static let proxySecretHeaderName = "X-FitLog-Proxy-Secret"
    static let muscleWikiAPIKeyHeaderName = "X-API-Key"

    private static func trimmed(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Optional shared secret sent as `X-FitLog-Proxy-Secret` when using the backend proxy.
    static var sharedSecret: String? {
        if let env = ProcessInfo.processInfo.environment["FITLOG_PROXY_SHARED_SECRET"].flatMap(trimmed) {
            return env
        }
        return (Bundle.main.object(forInfoDictionaryKey: "FITLOG_PROXY_SHARED_SECRET") as? String).flatMap(trimmed)
    }

    static func applyProxyAuthHeaders(to request: inout URLRequest) {
        guard let secret = sharedSecret else { return }
        request.setValue(secret, forHTTPHeaderField: proxySecretHeaderName)
    }

    /// Headers AVPlayer must send when fetching branded form-guide MP4s.
    /// Proxy mode needs the shared secret; direct MuscleWiki access needs the API key.
    static func videoStreamHeaders(
        usesProxy: Bool,
        proxySharedSecret: String?,
        muscleWikiAPIKey: String?
    ) -> [String: String] {
        if usesProxy {
            guard let secret = proxySharedSecret?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !secret.isEmpty else { return [:] }
            return [proxySecretHeaderName: secret]
        }
        guard let key = muscleWikiAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return [:] }
        return [muscleWikiAPIKeyHeaderName: key]
    }
}
