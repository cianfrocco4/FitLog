//
//  PriorWorkoutSubstitutionLookup.swift
//  FitLog
//
//  Finds the exercise performed in place of a planned row the last time this workout was completed.
//

import Foundation

struct PriorWorkoutSubstitution: Equatable, Sendable {
    let exerciseId: UUID
    let exerciseName: String
}

enum PriorWorkoutSubstitutionLookup {
    /// Library workout this session was started from, when it is still saved.
    static func libraryWorkout(
        for session: WorkoutSession,
        workoutById: (UUID) -> Workout?
    ) -> Workout? {
        if let originId = session.sessionPlanOrigin?.libraryWorkoutId,
           let workout = workoutById(originId) {
            return workout
        }
        return workoutById(session.workout.id)
    }

    /// Exercise used instead of the plan on the most recent completion of this workout.
    /// Returns nil when that session followed the plan, or when the row is already that exercise.
    static func lastSubstitution(
        for currentLog: ExerciseLog,
        exerciseIndex: Int,
        session: WorkoutSession,
        libraryWorkout: Workout?,
        completedSessions: [WorkoutSession]
    ) -> PriorWorkoutSubstitution? {
        let slotId = session.workout.templateSlotId(forWorkoutExerciseRow: currentLog.workoutExercise.id)
            ?? currentLog.workoutExercise.templateSlotId
            ?? libraryWorkout?.templateSlotId(forWorkoutExerciseRow: currentLog.workoutExercise.id)

        guard let latest = completedSessions
            .filter { belongs($0, library: libraryWorkout, sessionWorkoutId: session.workout.id) }
            .max(by: { ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast) })
        else { return nil }

        guard let historical = matchingLog(
            in: latest,
            workoutExerciseId: currentLog.workoutExercise.id,
            exerciseIndex: exerciseIndex,
            slotId: slotId,
            libraryExerciseCount: libraryWorkout?.exercises.count
        ), !historical.loggedSets.isEmpty,
        let performedId = historical.workoutExercise.exerciseId
        else { return nil }

        let plannedId = plannedExerciseId(
            library: libraryWorkout,
            workoutExerciseId: currentLog.workoutExercise.id,
            exerciseIndex: exerciseIndex,
            slotId: slotId
        )
        if let plannedId, performedId == plannedId { return nil }
        if performedId == currentLog.workoutExercise.exerciseId { return nil }

        let rawName = historical.workoutExercise.snapshot?.nameAtTimeOfLog ?? ""
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return PriorWorkoutSubstitution(
            exerciseId: performedId,
            exerciseName: name.isEmpty ? "Exercise" : name
        )
    }

    private static func belongs(
        _ session: WorkoutSession,
        library: Workout?,
        sessionWorkoutId: UUID
    ) -> Bool {
        guard session.endTime != nil else { return false }
        if let library {
            if session.sessionPlanOrigin?.libraryWorkoutId == library.id { return true }
            if session.sessionPlanOrigin == nil, session.workout.id == library.id { return true }
            return false
        }
        if session.workout.id == sessionWorkoutId { return true }
        return session.sessionPlanOrigin?.libraryWorkoutId == sessionWorkoutId
    }

    private static func matchingLog(
        in session: WorkoutSession,
        workoutExerciseId: UUID,
        exerciseIndex: Int,
        slotId: UUID?,
        libraryExerciseCount: Int?
    ) -> ExerciseLog? {
        if let exact = session.exerciseLogs.first(where: { $0.workoutExercise.id == workoutExerciseId }) {
            return exact
        }
        if let slotId {
            if let slotted = session.exerciseLogs.first(where: { row in
                let rowSlot = session.workout.templateSlotId(forWorkoutExerciseRow: row.workoutExercise.id)
                    ?? row.workoutExercise.templateSlotId
                return rowSlot == slotId
            }) {
                return slotted
            }
        }
        // Flexible sessions mint new row ids. Match by position only when the workout
        // still has the same number of exercises, so an added finisher cannot shift the row.
        guard let libraryExerciseCount,
              session.exerciseLogs.count == libraryExerciseCount,
              session.exerciseLogs.indices.contains(exerciseIndex)
        else { return nil }
        return session.exerciseLogs[exerciseIndex]
    }

    private static func plannedExerciseId(
        library: Workout?,
        workoutExerciseId: UUID,
        exerciseIndex: Int,
        slotId: UUID?
    ) -> UUID? {
        guard let library else { return nil }
        if let row = library.exercises.first(where: { $0.id == workoutExerciseId }) {
            return row.exerciseId
        }
        if let slotId,
           let row = library.exercises.first(where: { row in
               library.templateSlotId(forWorkoutExerciseRow: row.id) == slotId || row.templateSlotId == slotId
           }) {
            return row.exerciseId
        }
        guard library.exercises.indices.contains(exerciseIndex) else { return nil }
        return library.exercises[exerciseIndex].exerciseId
    }
}
