//
//  WidgetPlanSnapshot.swift
//  FitLog
//
//  Encodes today’s plan for a WidgetKit extension (same App Group). Reload timelines when data changes.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum FitLogWidgetSupport {
    /// Must match the App Group in entitlements and the widget extension.
    static let appGroupIdentifier = "group.com.acianfrocco.FitLog"
    static let snapshotKey = "fitlog.widget.todayPlan.v1"

    struct Snapshot: Codable, Equatable {
        var title: String
        var subtitle: String
        var isRest: Bool
        var hasLoggedWorkout: Bool
        var updatedAt: Date
    }

    static func writeSnapshot(from dataVM: DataManager) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        let cal = Calendar.current
        let today = Date()
        let resolved = dataVM.resolvedScheduleDay(for: today, calendar: cal)
        let logged = dataVM.primaryCompletedSession(on: today, calendar: cal) != nil

        let title: String
        let subtitle: String
        let isRest: Bool

        if logged, let s = dataVM.primaryCompletedSession(on: today, calendar: cal) {
            title = "Logged"
            subtitle = s.workout.name
            isRest = false
        } else {
            switch resolved {
            case .rest:
                title = "Rest day"
                subtitle = "Recovery"
                isRest = true
            case .unscheduled:
                title = "No session"
                subtitle = "Tap to plan"
                isRest = false
            case .workout(let ref):
                title = "Today"
                subtitle = dataVM.planLabel(for: ref)
                isRest = false
            }
        }

        let snap = Snapshot(
            title: title,
            subtitle: subtitle,
            isRest: isRest,
            hasLoggedWorkout: logged,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: snapshotKey)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

extension DataManager {
    /// Updates shared defaults for a home / lock screen widget (same App Group).
    func publishWidgetSnapshot() {
        FitLogWidgetSupport.writeSnapshot(from: self)
    }
}
