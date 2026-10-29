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
        publishAmethystTomorrowSnapshot()
    }

    func publishAmethystTomorrowSnapshot() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: completedSessions,
            tomorrowPlanTitle: resolvedPlanTitle(for: tomorrow),
            displayUnit: AmethystAskFitLog.storedDisplayUnit()
        )
        FitLogIntentBridge.publishAmethystTomorrowSnapshot(snapshot)
    }

    private func resolvedTodayPlanTitle() -> String? {
        resolvedPlanTitle(for: Date())
    }

    private func resolvedPlanTitle(for date: Date) -> String? {
        let day = resolvedScheduleDay(for: date)
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
