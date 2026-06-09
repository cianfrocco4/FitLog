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
        completedSessions: [WorkoutSession],
        dayOverrides: [String: ScheduleDayOverride] = [:],
        weekOverrides: [String: ScheduleWeekOverride] = [:],
        frozenCalendarDays: [String: FrozenPlanDay] = [:],
        asOf: Date = Date()
    ) {
        let todayStart = calendar.startOfDay(for: asOf)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return }

        var walkStart: Date
        if let oldest = completedSessions.filter(\.isCompleted).map({ calendar.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            walkStart = oldest
        } else if let fallback = calendar.date(byAdding: .day, value: -14, to: todayStart) {
            walkStart = fallback
        } else {
            walkStart = yesterday
        }

        let scheduleEngine = TrainingScheduleEngine(calendar: calendar)
        let overrideProgram = TrainingProgramState(
            cycleEntries: [],
            sessionsPerWeek: 0,
            preferredWeekdays: [],
            anchorDayKey: "",
            dayOverrides: dayOverrides,
            weekOverrides: weekOverrides
        )
        let context = ReconcileContext(
            scheduleEngine: scheduleEngine,
            overrideProgram: overrideProgram,
            frozenCalendarDays: frozenCalendarDays
        )

        var newSkips = state.skippedProgramTrainingDayKeys
        var walk = walkStart
        if walk > yesterday { return }

        while walk <= yesterday {
            let dk = TrainingProgramState.dayKey(for: walk, calendar: calendar)
            let resolved = reconcileResolution(on: walk, state: state, context: context)
            let done = hasCompletedWorkout(on: walk, sessions: completedSessions)
            switch resolved {
            case .training, .flex, .manualWorkout:
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

        applyOffDayMakeupCredits(
            state: state,
            completedSessions: completedSessions,
            context: context,
            skippedDayKeys: &newSkips
        )

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

    private struct ReconcileContext {
        let scheduleEngine: TrainingScheduleEngine
        let overrideProgram: TrainingProgramState
        let frozenCalendarDays: [String: FrozenPlanDay]
    }

    private enum ReconcileResolution {
        case training
        case flex
        case manualWorkout
        case rest
        case unscheduled
    }

    private func reconcileResolution(
        on date: Date,
        state: DynamicProgramState,
        context: ReconcileContext
    ) -> ReconcileResolution {
        let dayKey = TrainingProgramState.dayKey(for: date, calendar: calendar)
        if let frozen = context.frozenCalendarDays[dayKey] {
            switch frozen.asResolved() {
            case .rest:
                return .rest
            case .unscheduled:
                return .unscheduled
            case .workout:
                return .manualWorkout
            }
        }

        if let overridden = context.scheduleEngine.resolveOverriddenDay(date: date, program: context.overrideProgram) {
            switch overridden {
            case .rest:
                return .rest
            case .unscheduled:
                return .unscheduled
            case .workout:
                return .manualWorkout
            }
        }

        let resolved = periodization.resolvedTemplateDay(on: date, state: state)
        switch resolved {
        case .training:
            return .training
        case .flex:
            return .flex
        case .rest:
            return .rest
        case .unscheduled:
            return .unscheduled
        }
    }

    /// Credits off-day makeup sessions whose `sessionPlanOrigin` matches an outstanding missed planned template.
    private func applyOffDayMakeupCredits(
        state: DynamicProgramState,
        completedSessions: [WorkoutSession],
        context: ReconcileContext,
        skippedDayKeys: inout Set<String>
    ) {
        let workoutToTemplate = Dictionary(
            state.materializedTemplateWorkoutIds.map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !workoutToTemplate.isEmpty, !skippedDayKeys.isEmpty else { return }

        var creditsByTemplate: [UUID: Int] = [:]
        for session in completedSessions where session.isCompleted {
            let completionDay = calendar.startOfDay(for: session.endTime ?? session.startTime)
            let resolution = reconcileResolution(on: completionDay, state: state, context: context)
            guard resolution == .rest || resolution == .unscheduled else { continue }
            guard let origin = session.sessionPlanOrigin,
                  case .workout(let workoutId) = origin,
                  let templateId = workoutToTemplate[workoutId]
            else { continue }
            creditsByTemplate[templateId, default: 0] += 1
        }

        guard !creditsByTemplate.isEmpty else { return }

        var templateIdByDayKey: [String: UUID] = [:]
        for dayKey in skippedDayKeys.sorted() {
            guard let date = TrainingProgramState.date(fromDayKey: dayKey, calendar: calendar),
                  let templateId = plannedTemplateId(on: date, state: state)
            else { continue }
            templateIdByDayKey[dayKey] = templateId
        }

        for dayKey in skippedDayKeys.sorted() {
            guard let templateId = templateIdByDayKey[dayKey],
                  let remaining = creditsByTemplate[templateId], remaining > 0
            else { continue }
            skippedDayKeys.remove(dayKey)
            creditsByTemplate[templateId] = remaining - 1
        }
    }

    /// Template that was planned on a training day, evaluated as if that day were not skipped.
    private func plannedTemplateId(on date: Date, state: DynamicProgramState) -> UUID? {
        let dayKey = TrainingProgramState.dayKey(for: date, calendar: calendar)
        var probe = state
        probe.skippedProgramTrainingDayKeys.remove(dayKey)
        let resolved = periodization.resolvedTemplateDay(on: date, state: probe)
        switch resolved {
        case .training(let template), .flex(let template):
            return template.id
        case .rest, .unscheduled:
            return nil
        }
    }

    private func hasCompletedWorkout(on day: Date, sessions: [WorkoutSession]) -> Bool {
        sessions.contains { session in
            guard session.isCompleted else { return false }
            let t = session.endTime ?? session.startTime
            return calendar.isDate(t, inSameDayAs: day)
        }
    }
}
