//
//  LibraryWorkoutLastSessionCopy.swift
//  FitLog
//
//  Last-session recap for a saved library workout or a single exercise.
//  Used by the workout editor, Personal Records, and exercise detail — not Home
//  start pickers or History Explore rows (those live on other nightly branches).
//

import Foundation

enum LibraryWorkoutLastSessionCopy {
    struct Recap: Equatable {
        /// Relative last-trained line (`Last done today` / `yesterday` / `Nd ago`).
        let lastDoneLine: String
        /// Last working load or cardio duration (warm-ups skipped).
        let loadLine: String
        /// Exercise name when the load line is a strength set.
        let exerciseName: String?
        let endedAt: Date

        var accessibilityLabel: String {
            if let exerciseName, !exerciseName.isEmpty {
                return "\(lastDoneLine), last working \(exerciseName) \(loadLine)"
            }
            return "\(lastDoneLine), last working \(loadLine)"
        }
    }

    /// Most recent completed session for a library workout (plan origin, or legacy matching workout id).
    static func lastCompletedSession(
        libraryWorkoutId: UUID,
        in sessions: [WorkoutSession]
    ) -> WorkoutSession? {
        let planRef = WorkoutPlanRef.workout(libraryWorkoutId)
        return sessions
            .filter { session in
                guard session.endTime != nil else { return false }
                if session.sessionPlanOrigin == planRef { return true }
                if session.sessionPlanOrigin == nil, session.workout.id == libraryWorkoutId { return true }
                return false
            }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    /// Most recent completed session that logged this library exercise.
    static func lastCompletedSession(
        containingExerciseId exerciseId: UUID,
        in sessions: [WorkoutSession]
    ) -> WorkoutSession? {
        sessions
            .filter { session in
                guard session.endTime != nil else { return false }
                return session.exerciseLogs.contains { $0.workoutExercise.exerciseId == exerciseId }
            }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    static func recap(
        forLibraryWorkoutId libraryId: UUID,
        sessions: [WorkoutSession],
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let session = lastCompletedSession(libraryWorkoutId: libraryId, in: sessions) else {
            return nil
        }
        return recap(from: session, exerciseId: nil, weightUnit: weightUnit, now: now, calendar: calendar)
    }

    static func recap(
        forExerciseId exerciseId: UUID,
        sessions: [WorkoutSession],
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let session = lastCompletedSession(containingExerciseId: exerciseId, in: sessions) else {
            return nil
        }
        return recap(from: session, exerciseId: exerciseId, weightUnit: weightUnit, now: now, calendar: calendar)
    }

    static func recap(
        from session: WorkoutSession,
        exerciseId: UUID?,
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let endedAt = session.endTime else { return nil }
        let lastDoneLine = HomeWorkoutFormatting.lastDoneLabel(for: endedAt, reference: now, calendar: calendar)

        if let exerciseId {
            if let working = lastWorkingLoad(in: session, exerciseId: exerciseId, weightUnit: weightUnit) {
                return Recap(
                    lastDoneLine: lastDoneLine,
                    loadLine: working.loadLine,
                    exerciseName: working.exerciseName,
                    endedAt: endedAt
                )
            }
            if let cardio = lastCardioSummary(in: session, exerciseId: exerciseId) {
                return Recap(
                    lastDoneLine: lastDoneLine,
                    loadLine: cardio,
                    exerciseName: nil,
                    endedAt: endedAt
                )
            }
        }

        if let working = lastWorkingLoad(in: session, exerciseId: nil, weightUnit: weightUnit) {
            return Recap(
                lastDoneLine: lastDoneLine,
                loadLine: working.loadLine,
                exerciseName: working.exerciseName,
                endedAt: endedAt
            )
        }
        if let cardio = lastCardioSummary(in: session, exerciseId: nil) {
            return Recap(
                lastDoneLine: lastDoneLine,
                loadLine: cardio,
                exerciseName: nil,
                endedAt: endedAt
            )
        }

        let durationSeconds = max(0, Int(endedAt.timeIntervalSince(session.startTime)))
        guard durationSeconds > 0 else { return nil }
        return Recap(
            lastDoneLine: lastDoneLine,
            loadLine: HistoryFormatters.formatAvgDuration(durationSeconds),
            exerciseName: nil,
            endedAt: endedAt
        )
    }

    /// Library workout to start for this exercise: last session's plan origin, else a saved workout that includes the movement.
    static func libraryWorkoutToStart(
        forExerciseId exerciseId: UUID,
        library: [Workout],
        sessions: [WorkoutSession]
    ) -> Workout? {
        if let session = lastCompletedSession(containingExerciseId: exerciseId, in: sessions) {
            if let originId = session.sessionPlanOrigin?.libraryWorkoutId,
               let workout = library.first(where: { $0.id == originId }) {
                return workout
            }
            if let workout = library.first(where: { $0.id == session.workout.id }) {
                return workout
            }
        }
        return library.first { workout in
            workout.exercises.contains { $0.exerciseId == exerciseId }
        }
    }

    private static func lastWorkingLoad(
        in session: WorkoutSession,
        exerciseId: UUID?,
        weightUnit: WeightDisplayUnit
    ) -> (exerciseName: String, loadLine: String)? {
        for log in session.exerciseLogs {
            if let exerciseId, log.workoutExercise.exerciseId != exerciseId { continue }
            guard let set = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) else { continue }
            return (exerciseName(for: log), set.weightRepsDisplaySummary(displayUnit: weightUnit))
        }
        return nil
    }

    private static func lastCardioSummary(
        in session: WorkoutSession,
        exerciseId: UUID?
    ) -> String? {
        for log in session.exerciseLogs {
            if let exerciseId, log.workoutExercise.exerciseId != exerciseId { continue }
            guard let set = log.loggedSets.last(where: { $0.countsTowardCardioTotals }) else { continue }
            let summary = set.cardioDisplaySummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty { return summary }
        }
        return nil
    }

    private static func exerciseName(for log: ExerciseLog) -> String {
        if let snap = log.workoutExercise.snapshot {
            let name = snap.nameAtTimeOfLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return log.workoutExercise.slotLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
func startLibraryWorkoutOpeningLogSheet(
    _ workout: Workout,
    dataVM: DataManager,
    currentVM: CurrentWorkoutSessionViewModel,
    openCurrentWorkoutSheet: (() -> Void)?,
    setPendingReplace: (PendingWorkoutReplace?) -> Void
) {
    let toStart = workout.hasFlexibleSlots ? dataVM.sessionInstance(from: workout) : workout
    currentVM.startWorkoutResolvingConflict(
        toStart,
        sessionPlanOrigin: .workout(workout.id),
        onNeedReplaceConfirmation: setPendingReplace
    )
    if currentVM.isInProgress {
        openCurrentWorkoutSheet?()
    }
}
