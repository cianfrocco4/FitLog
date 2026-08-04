//
//  CloudAIUsageQuota.swift
//  FitLog
//
//  Soft local daily caps for cloud AI / form-guide calls (UX + cost soft-brake).
//  Not a security boundary — the proxy enforces real rate limits.
//

import Foundation

enum CloudAIUsageKind: String, Sendable {
    case coachChat
    case programGeneration
    case formGuide
}

enum CloudAIUsageQuota {
    private static let dayKeyPrefix = "fitlog.cloudAI.quota.day."
    private static let countKeyPrefix = "fitlog.cloudAI.quota.count."

    /// Soft daily defaults (local device). Proxy IP limits remain the hard backstop.
    static func dailyLimit(for kind: CloudAIUsageKind) -> Int {
        switch kind {
        case .coachChat: return 40
        case .programGeneration: return 12
        case .formGuide: return 80
        }
    }

    static var dailyLimitReachedMessage: String {
        "Daily AI limit reached — try again tomorrow."
    }

    static func remaining(for kind: CloudAIUsageKind, now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        rollForwardIfNeeded(kind: kind, now: now, defaults: defaults)
        let used = defaults.integer(forKey: countKey(for: kind))
        return max(0, dailyLimit(for: kind) - used)
    }

    static func canConsume(_ kind: CloudAIUsageKind, now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        remaining(for: kind, now: now, defaults: defaults) > 0
    }

    @discardableResult
    static func consume(_ kind: CloudAIUsageKind, now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard canConsume(kind, now: now, defaults: defaults) else { return false }
        let key = countKey(for: kind)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        return true
    }

    /// Test / erase seam.
    static func resetAll(defaults: UserDefaults = .standard) {
        for kind in [CloudAIUsageKind.coachChat, .programGeneration, .formGuide] {
            defaults.removeObject(forKey: dayKey(for: kind))
            defaults.removeObject(forKey: countKey(for: kind))
        }
    }

    private static func rollForwardIfNeeded(kind: CloudAIUsageKind, now: Date, defaults: UserDefaults) {
        let today = dayStamp(for: now)
        let key = dayKey(for: kind)
        if defaults.string(forKey: key) != today {
            defaults.set(today, forKey: key)
            defaults.set(0, forKey: countKey(for: kind))
        }
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dayKey(for kind: CloudAIUsageKind) -> String {
        dayKeyPrefix + kind.rawValue
    }

    private static func countKey(for kind: CloudAIUsageKind) -> String {
        countKeyPrefix + kind.rawValue
    }
}
