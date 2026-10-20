//
//  JadeLastWorkingLoad.swift
//  FitLog
//
//  Last working load / last cardio duration for History charts, PR celebration,
//  and the logging chip so yesterday stays visible without a Home round trip.
//

import Foundation

enum JadeLastWorkingLoad {
    /// Newest completed session wins. Strength working sets beat cardio on the same log.
    static func captionsByExerciseId(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs {
                guard let id = log.workoutExercise.exerciseId, result[id] == nil else { continue }
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    result[id] = caption
                }
            }
        }
        return result
    }

    static func caption(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    return caption
                }
            }
        }
        return nil
    }

    static func caption(
        for workoutExercise: WorkoutExercise,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        guard let id = workoutExercise.exerciseId else { return nil }
        return caption(
            for: id,
            from: sessions,
            displayUnit: displayUnit,
            excludingSessionId: excludingSessionId
        )
    }

    /// First concrete exercise on the workout that has a last working load or last cardio duration.
    static func caption(
        for workout: Workout,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for row in workout.exercises {
            if let caption = caption(
                for: row,
                from: sessions,
                displayUnit: displayUnit,
                excludingSessionId: excludingSessionId
            ) {
                return caption
            }
        }
        return nil
    }

    /// First slot on the day that resolves to a library exercise with history.
    static func caption(
        forDay day: SplitBuilderEditableDay,
        from sessions: [WorkoutSession],
        library: [Exercise],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for slot in day.slots {
            guard let id = resolvedExerciseId(for: slot, library: library) else { continue }
            if let caption = caption(
                for: id,
                from: sessions,
                displayUnit: displayUnit,
                excludingSessionId: excludingSessionId
            ) {
                return caption
            }
        }
        return nil
    }

    /// First matching day in list order.
    static func caption(
        forDays days: [SplitBuilderEditableDay],
        from sessions: [WorkoutSession],
        library: [Exercise],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for day in days {
            if let caption = caption(
                forDay: day,
                from: sessions,
                library: library,
                displayUnit: displayUnit,
                excludingSessionId: excludingSessionId
            ) {
                return caption
            }
        }
        return nil
    }

    /// First resolvable slot on this block’s weekly templates.
    static func caption(
        forBlock block: ProgramBlock,
        from sessions: [WorkoutSession],
        library: [Exercise],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        let days = block.weeklyTemplates.map {
            SplitBuilderEditableDay(
                id: $0.id,
                name: $0.dayName,
                focus: $0.focus,
                slots: $0.slots,
                dayNotes: $0.dayNotes
            )
        }
        return caption(
            forDays: days,
            from: sessions,
            library: library,
            displayUnit: displayUnit,
            excludingSessionId: excludingSessionId
        )
    }

    /// First resolvable slot across program blocks (weekly templates in block order).
    static func caption(
        forProgram program: DynamicProgram,
        from sessions: [WorkoutSession],
        library: [Exercise],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for block in program.blocks {
            if let caption = caption(
                forBlock: block,
                from: sessions,
                library: library,
                displayUnit: displayUnit,
                excludingSessionId: excludingSessionId
            ) {
                return caption
            }
        }
        return nil
    }

    /// First library workout in plan order that has a last working load or last cardio duration.
    static func caption(
        forPlanWorkouts workouts: [Workout],
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for workout in workouts {
            if let caption = caption(
                for: workout,
                from: sessions,
                displayUnit: displayUnit,
                excludingSessionId: excludingSessionId
            ) {
                return caption
            }
        }
        return nil
    }

    /// Slot’s linked library exercise, else newest completed working load or cardio duration.
    static func caption(
        forSlot slot: SplitBuilderEditableSlot,
        from sessions: [WorkoutSession],
        library: [Exercise],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        if let id = resolvedExerciseId(for: slot, library: library),
           let caption = caption(
            for: id,
            from: sessions,
            displayUnit: displayUnit,
            excludingSessionId: excludingSessionId
           ) {
            return caption
        }
        return newestCompletedCaption(
            from: sessions,
            displayUnit: displayUnit,
            excludingSessionId: excludingSessionId
        )
    }

    /// Override id wins; otherwise link the suggested name through the library.
    static func resolvedExerciseId(
        for slot: SplitBuilderEditableSlot,
        library: [Exercise]
    ) -> UUID? {
        if let oid = slot.suggestedExerciseOverrideId {
            return oid
        }
        guard let raw = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if case .linked(let ex) = ExerciseNameResolution.resolve(planName: raw, library: library) {
            return ex.id
        }
        return nil
    }

    /// Newest completed session's first working load or cardio duration (any exercise).
    static func newestCompletedCaption(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> String? {
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs {
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    return caption
                }
            }
        }
        return nil
    }

    /// Last working-set weight in the user's display unit, skipping warm-ups.
    static func lastWorkingDisplayWeight(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        excludingSessionId: UUID? = nil
    ) -> Double? {
        guard let set = lastWorkingSet(
            for: exerciseId,
            from: sessions,
            excludingSessionId: excludingSessionId
        ) else { return nil }
        return WeightStoreConversion.displayValue(storedPounds: set.weight, unit: displayUnit)
    }

    /// Last cardio duration in seconds, skipping interval rest. Nil when none exists.
    static func lastCardioDurationSec(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        excludingSessionId: UUID? = nil
    ) -> Int? {
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let sec = lastCardioDurationSec(in: log) {
                    return sec
                }
            }
        }
        return nil
    }

    /// Most recent cardio duration from any exercise in prior completed sessions.
    static func lastCardioDurationCaption(
        from sessions: [WorkoutSession],
        excludingSessionId: UUID? = nil
    ) -> String? {
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs {
                if let sec = lastCardioDurationSec(in: log) {
                    return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
                }
            }
        }
        return nil
    }

    // MARK: - Private

    private static func completedNewestFirst(
        _ sessions: [WorkoutSession],
        excludingSessionId: UUID?
    ) -> [WorkoutSession] {
        sessions
            .filter { $0.isCompleted && $0.id != excludingSessionId }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func lastWorkingSet(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        excludingSessionId: UUID?
    ) -> LoggedSet? {
        for session in completedNewestFirst(sessions, excludingSessionId: excludingSessionId) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                    return working
                }
            }
        }
        return nil
    }

    private static func caption(from log: ExerciseLog, displayUnit: WeightDisplayUnit) -> String? {
        if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = lastCardioDurationSec(in: log) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
