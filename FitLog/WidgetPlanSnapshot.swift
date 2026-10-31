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
        publishOnyxNextPlanSnapshot()
    }

    func publishOnyxNextPlanSnapshot() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayLong = DateFormatter()
        weekdayLong.calendar = calendar
        weekdayLong.locale = .current
        weekdayLong.dateFormat = "EEEE"
        let weekdayShort = DateFormatter()
        weekdayShort.calendar = calendar
        weekdayShort.locale = .current
        weekdayShort.dateFormat = "EEE"

        var upcoming: [FitLogIntentBridge.OnyxUpcomingTraining] = []
        for offset in 1...14 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard case .workout(let ref) = resolvedScheduleDay(for: date, calendar: calendar) else {
                continue
            }
            let name = userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })?.name ?? "Workout"
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard OnyxAskFitLog.isStartableWorkoutName(trimmed) else { continue }
            upcoming.append(
                FitLogIntentBridge.OnyxUpcomingTraining(
                    weekdayLabel: weekdayLong.string(from: date),
                    workoutName: trimmed
                )
            )
        }

        let weekLines = TrainingProgramState.orderedCalendarDaysInWeek(
            containing: today,
            calendar: calendar
        ).map { dayStart -> String in
            let label = weekdayShort.string(from: dayStart)
            switch resolvedScheduleDay(for: dayStart, calendar: calendar) {
            case .rest:
                return "\(label) Rest"
            case .unscheduled:
                return "\(label) —"
            case .workout(let ref):
                let name = userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })?.name ?? "Workout"
                return "\(label) \(name)"
            }
        }

        let snapshot = OnyxAskFitLog.querySnapshot(
            from: completedSessions,
            upcomingTrainingDays: upcoming,
            thisWeekPlanLines: weekLines,
            displayUnit: OnyxAskFitLog.storedDisplayUnit()
        )
        FitLogIntentBridge.publishOnyxNextPlanSnapshot(snapshot)
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
