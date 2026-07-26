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
