//
//  ScheduleAdaptationService.swift
//  FitLog
//
//  Detects missed planned sessions, manages busy-day keys, and applies block shift hints.
//

import Foundation

struct ScheduleAdaptationService: Sendable {
    var calendar: Calendar
    var periodization: PeriodizationEngine

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.periodization = PeriodizationEngine(calendar: calendar)
    }

    // MARK: - Missed sessions

    /// Day keys where a training or flex session was planned but no completed workout exists that calendar day.
    func missedPlannedTrainingDayKeys(
        from start: Date,
        through end: Date,
        state: DynamicProgramState,
        completedSessions: [WorkoutSession]
    ) -> Set<String> {
        var misses: Set<String> = []
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return misses }

        var walk = startDay
        while walk <= endDay {
            let resolved = periodization.resolvedTemplateDay(on: walk, state: state)
            switch resolved {
            case .training, .flex:
                let dk = TrainingProgramState.dayKey(for: walk, calendar: calendar)
                if !hasCompletedWorkout(on: walk, sessions: completedSessions) {
                    misses.insert(dk)
                }
            case .rest, .unscheduled:
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = next
        }
        return misses
    }

    /// Merges detected misses through `end` into `state.missedSessionDayKeys`.
    func mergeDetectedMisses(
        through end: Date,
        state: inout DynamicProgramState,
        completedSessions: [WorkoutSession]
    ) {
        let anchor = calendar.startOfDay(for: state.anchorDate)
        let endDay = calendar.startOfDay(for: end)
        guard endDay >= anchor else { return }
        let misses = missedPlannedTrainingDayKeys(
            from: anchor,
            through: endDay,
            state: state,
            completedSessions: completedSessions
        )
        state.missedSessionDayKeys.formUnion(misses)
    }

    /// Reconciles skipped rotation keys for missed **planned** training days (mirrors `DataManager.reconcileSkippedCycleTrainingDays` intent).
    func mergeSkippedRotationKeysThroughYesterday(
        state: inout DynamicProgramState,
        completedSessions: [WorkoutSession]
    ) {
        let todayStart = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return }

        var walkStart: Date
        if let oldest = completedSessions.filter(\.isCompleted).map({ calendar.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            walkStart = oldest
        } else if let fallback = calendar.date(byAdding: .day, value: -14, to: todayStart) {
            walkStart = fallback
        } else {
            walkStart = yesterday
        }

        var newSkips = state.skippedProgramTrainingDayKeys
        var walk = walkStart
        if walk > yesterday { return }

        while walk <= yesterday {
            let dk = TrainingProgramState.dayKey(for: walk, calendar: calendar)
            let resolved = periodization.resolvedTemplateDay(on: walk, state: state)
            let done = hasCompletedWorkout(on: walk, sessions: completedSessions)
            switch resolved {
            case .training, .flex:
                if done {
                    newSkips.remove(dk)
                } else {
                    newSkips.insert(dk)
                }
            case .rest, .unscheduled:
                newSkips.remove(dk)
            }
            guard let nx = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = nx
        }
        state.skippedProgramTrainingDayKeys = newSkips
    }

    // MARK: - Busy days

    func setBusyDay(dayKey: String, isBusy: Bool, state: inout DynamicProgramState) {
        if isBusy {
            state.busyDayKeys.insert(dayKey)
        } else {
            state.busyDayKeys.remove(dayKey)
        }
    }

    // MARK: - Block shift (`.shift` policy support)

    /// Adds calendar days to a block’s span (`DynamicProgramState.blockShiftDays`).
    func extendBlockShift(blockId: UUID, additionalDays: Int, state: inout DynamicProgramState) {
        guard additionalDays != 0 else { return }
        let current = state.blockShiftDays[blockId] ?? 0
        state.blockShiftDays[blockId] = max(0, current + additionalDays)
    }

    // MARK: - Helpers

    private func hasCompletedWorkout(on day: Date, sessions: [WorkoutSession]) -> Bool {
        sessions.contains { session in
            guard session.isCompleted else { return false }
            let t = session.endTime ?? session.startTime
            return calendar.isDate(t, inSameDayAs: day)
        }
    }
}
