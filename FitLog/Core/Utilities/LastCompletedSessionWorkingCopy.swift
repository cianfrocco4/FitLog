//
//  LastCompletedSessionWorkingCopy.swift
//  FitLog
//
//  Last-session working load (warm-ups skipped) and a fresh Start from History /
//  Exercise Library / Home week-in-review. Unique vs other nightly helpers:
//  LastSessionWorkingRecap (e2c4), LibraryWorkoutLastSessionCopy (a209),
//  HistoryStartFreshWorkout (9816/a831).
//

import Foundation

enum LastCompletedSessionWorkingCopy {
    struct Recap: Equatable {
        let workoutName: String
        /// `Last done today` / `yesterday` / `Nd ago`.
        let lastDoneLine: String
        /// Last working load or cardio duration (warm-ups skipped).
        let loadLine: String
        /// Exercise name when the load line is a strength set.
        let exerciseName: String?
        let endedAt: Date

        var subtitleLine: String {
            if let exerciseName, !exerciseName.isEmpty {
                return "\(lastDoneLine) · \(exerciseName) · \(loadLine)"
            }
            return "\(lastDoneLine) · \(loadLine)"
        }

        var accessibilityLabel: String {
            if let exerciseName, !exerciseName.isEmpty {
                return "\(workoutName), \(lastDoneLine), last working \(exerciseName) \(loadLine)"
            }
            return "\(workoutName), \(lastDoneLine), last working \(loadLine)"
        }
    }

    static func latestCompletedSession(in sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions
            .filter { $0.endTime != nil }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    static func recap(
        from session: WorkoutSession,
        exerciseId: UUID? = nil,
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let endedAt = session.endTime else { return nil }
        let lastDoneLine = HomeWorkoutFormatting.lastDoneLabel(for: endedAt, reference: now, calendar: calendar)
        let workoutName = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let exerciseId {
            if let working = lastWorkingLoad(in: session, exerciseId: exerciseId, weightUnit: weightUnit) {
                return Recap(
                    workoutName: workoutName,
                    lastDoneLine: lastDoneLine,
                    loadLine: working.loadLine,
                    exerciseName: working.exerciseName,
                    endedAt: endedAt
                )
            }
            if let cardio = lastCardioSummary(in: session, exerciseId: exerciseId) {
                return Recap(
                    workoutName: workoutName,
                    lastDoneLine: lastDoneLine,
                    loadLine: cardio,
                    exerciseName: nil,
                    endedAt: endedAt
                )
            }
        }

        if let working = lastWorkingLoad(in: session, exerciseId: nil, weightUnit: weightUnit) {
            return Recap(
                workoutName: workoutName,
                lastDoneLine: lastDoneLine,
                loadLine: working.loadLine,
                exerciseName: working.exerciseName,
                endedAt: endedAt
            )
        }

        if let cardio = lastCardioSummary(in: session, exerciseId: nil) {
            return Recap(
                workoutName: workoutName,
                lastDoneLine: lastDoneLine,
                loadLine: cardio,
                exerciseName: nil,
                endedAt: endedAt
            )
        }

        let durationSeconds = max(0, Int(endedAt.timeIntervalSince(session.startTime)))
        guard durationSeconds > 0 else { return nil }
        return Recap(
            workoutName: workoutName,
            lastDoneLine: lastDoneLine,
            loadLine: HistoryFormatters.formatAvgDuration(durationSeconds),
            exerciseName: nil,
            endedAt: endedAt
        )
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

    /// Library workout when the finished session still points at one; otherwise the session snapshot.
    static func sourceWorkout(session: WorkoutSession, library: [Workout]) -> Workout? {
        if let id = session.sessionPlanOrigin?.libraryWorkoutId,
           let found = library.first(where: { $0.id == id }),
           !found.exercises.isEmpty {
            return found
        }
        return session.workout.exercises.isEmpty ? nil : session.workout
    }

    /// Library workout to start for this exercise: last session's plan origin, else a saved workout that includes the movement.
    static func libraryWorkoutToStart(
        forExerciseId exerciseId: UUID,
        library: [Workout],
        sessions: [WorkoutSession]
    ) -> Workout? {
        if let session = lastCompletedSession(containingExerciseId: exerciseId, in: sessions) {
            if let originId = session.sessionPlanOrigin?.libraryWorkoutId,
               let workout = library.first(where: { $0.id == originId }),
               !workout.exercises.isEmpty {
                return workout
            }
            if let workout = library.first(where: { $0.id == session.workout.id }),
               !workout.exercises.isEmpty {
                return workout
            }
        }
        return library.first { workout in
            !workout.exercises.isEmpty && workout.exercises.contains { $0.exerciseId == exerciseId }
        }
    }

    /// Starts a **new** session and leaves the finished History entry intact.
    @MainActor
    static func startFresh(
        from session: WorkoutSession,
        dataVM: DataManager,
        currentVM: CurrentWorkoutSessionViewModel,
        openCurrentWorkoutSheet: (() -> Void)?,
        setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
    ) {
        guard let source = sourceWorkout(session: session, library: dataVM.userWorkouts) else { return }
        startLibraryWorkout(
            source,
            dataVM: dataVM,
            currentVM: currentVM,
            originHint: session.sessionPlanOrigin,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: setPendingReplace
        )
    }

    @MainActor
    static func startLibraryWorkout(
        _ workout: Workout,
        dataVM: DataManager,
        currentVM: CurrentWorkoutSessionViewModel,
        originHint: WorkoutPlanRef? = nil,
        openCurrentWorkoutSheet: (() -> Void)?,
        setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
    ) {
        let toStart = workout.hasFlexibleSlots ? dataVM.sessionInstance(from: workout) : workout
        let origin: WorkoutPlanRef? = {
            if dataVM.workout(id: workout.id) != nil {
                return .workout(workout.id)
            }
            return originHint
        }()
        currentVM.startWorkoutResolvingConflict(toStart, sessionPlanOrigin: origin) {
            setPendingReplace($0)
        }
        if currentVM.isInProgress {
            openCurrentWorkoutSheet?()
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
