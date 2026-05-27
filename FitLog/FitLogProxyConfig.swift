//
//  FitLogProxyConfig.swift
//  FitLog
//
//  Shared secret for authenticated backend proxy requests.
//

import Foundation

enum FitLogProxyConfig {
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
        request.setValue(secret, forHTTPHeaderField: "X-FitLog-Proxy-Secret")
    }
}
