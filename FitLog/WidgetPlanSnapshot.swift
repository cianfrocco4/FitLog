//
//  WidgetPlanSnapshot.swift
//  FitLog
//

import Foundation
import WidgetKit

extension DataManager {
    func publishWidgetSnapshot(readiness: ReadinessScore? = nil, todayPlanTitle: String? = nil) {
        let dayKey = TrainingProgramState.dayKey(for: Date())
        let score = readiness ?? readinessStore.load(dayKey: dayKey)
        let planTitle = todayPlanTitle ?? resolvedTodayPlanTitle()
        let payload = WidgetSnapshotStore.Payload(
            readinessScore: score?.score,
            readinessSummary: score?.summary,
            readinessBandTitle: score?.band.displayTitle,
            todayPlanTitle: planTitle,
            updatedAt: Date()
        )
        if WidgetSnapshotStore.writeIfChanged(payload) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func resolvedTodayPlanTitle() -> String? {
        let day = resolvedScheduleDay(for: Date())
        switch day {
        case .rest:
            return "Rest day"
        case .unscheduled:
            return "No plan scheduled"
        case .workout(let ref):
            return userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })?.name ?? "Workout"
        }
    }
}
