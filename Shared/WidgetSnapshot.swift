//
//  WidgetSnapshot.swift
//  FitLog
//
//  App Group payload shared between the app and home screen widgets.
//

import Foundation

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.acianfrocco.FitLog.shared"
    static let snapshotKey = "fitlog.widget.snapshot.v1"

    struct Payload: Codable, Sendable, Equatable {
        var readinessScore: Int?
        var readinessSummary: String?
        var readinessBandTitle: String?
        var todayPlanTitle: String?
        var updatedAt: Date
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(_ payload: Payload) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    /// Writes only when semantic widget content changed. Returns true when a new payload was stored.
    @discardableResult
    static func writeIfChanged(_ payload: Payload) -> Bool {
        if let existing = read(), semanticContent(of: existing) == semanticContent(of: payload) {
            return false
        }
        write(payload)
        return true
    }

    static func read() -> Payload? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    static func clear() {
        sharedDefaults?.removeObject(forKey: snapshotKey)
    }

    private static func semanticContent(of payload: Payload) -> SemanticContent {
        SemanticContent(
            readinessScore: payload.readinessScore,
            readinessSummary: payload.readinessSummary,
            readinessBandTitle: payload.readinessBandTitle,
            todayPlanTitle: payload.todayPlanTitle
        )
    }

    private struct SemanticContent: Equatable {
        var readinessScore: Int?
        var readinessSummary: String?
        var readinessBandTitle: String?
        var todayPlanTitle: String?
    }
}

/// Shared copy helpers for readiness widget freshness (app + widget extension).
enum WidgetSnapshotFreshness {
    /// Snapshots older than this are labeled as potentially outdated on medium widgets.
    static let staleAfter: TimeInterval = 24 * 60 * 60

    static func isStale(updatedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(updatedAt) >= staleAfter
    }

    /// Caption shown under the readiness score on medium widgets.
    static func updatedCaption(
        updatedAt: Date,
        now: Date = Date(),
        relativePhrase: String? = nil
    ) -> String {
        let phrase = relativePhrase ?? relativeUpdatedPhrase(updatedAt: updatedAt, now: now)
        if isStale(updatedAt: updatedAt, now: now) {
            return "Updated \(phrase) · May be outdated"
        }
        return "Updated \(phrase)"
    }

    /// Spoken freshness suffix for VoiceOver.
    static func accessibilityUpdatedSuffix(
        updatedAt: Date,
        now: Date = Date(),
        relativePhrase: String? = nil
    ) -> String {
        let phrase = relativePhrase ?? relativeUpdatedPhrase(updatedAt: updatedAt, now: now)
        if isStale(updatedAt: updatedAt, now: now) {
            return "Updated \(phrase), may be outdated"
        }
        return "Updated \(phrase)"
    }

    static func relativeUpdatedPhrase(updatedAt: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: updatedAt, relativeTo: now)
    }
}
