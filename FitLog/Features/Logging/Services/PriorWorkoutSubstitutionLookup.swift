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

/// What was actually performed for this workout row the last time the workout was completed.
struct PriorWorkoutPerformance {
    let performedName: String
    let plannedName: String?
    /// True when the last session used a different exercise than the plan for this row.
    let wasSwapped: Bool
    let sets: [LoggedSet]
    let configurationFields: [String]
    let performedAt: Date

    /// One setup line when every logged set used the same configuration.
    var sharedSetupSummary: String? {
        var unique: [String] = []
        for line in sets.map({ $0.configurationSummary(fieldNames: configurationFields) }) where !line.isEmpty {
            if !unique.contains(line) {
                unique.append(line)
            }
        }
        guard unique.count == 1 else { return nil }
        return unique[0]
    }

    static func relativeTitle(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Last time · today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Last time · yesterday"
        }
        let start = calendar.startOfDay(for: date)
        let ref = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: ref).day ?? 0
        if days > 1 && days < 14 {
            return "Last time · \(days)d ago"
        }
        return "Last time · \(date.formatted(date: .abbreviated, time: .omitted))"
    }
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

        let matchingSessions = completedSessions.filter {
            belongs($0, library: libraryWorkout, sessionWorkoutId: session.workout.id)
        }
        guard let latest = matchingSessions.max(by: {
            ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast)
        }) else {
            return nil
        }

        guard let historical = matchingLog(
            in: latest,
            workoutExerciseId: currentLog.workoutExercise.id,
            exerciseIndex: exerciseIndex,
            slotId: slotId,
            libraryExerciseCount: libraryWorkout?.exercises.count
        ) else {
            return nil
        }
        guard !historical.loggedSets.isEmpty else { return nil }
        guard let performedId = historical.workoutExercise.exerciseId else { return nil }

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

    /// Last completion of this workout row, including swaps, setup, and every logged set.
    /// Prefers the same workout. Returns nil when that session has no logged sets for the row.
    static func lastPerformance(
        for currentLog: ExerciseLog,
        exerciseIndex: Int,
        session: WorkoutSession,
        libraryWorkout: Workout?,
        completedSessions: [WorkoutSession]
    ) -> PriorWorkoutPerformance? {
        let slotId = session.workout.templateSlotId(forWorkoutExerciseRow: currentLog.workoutExercise.id)
            ?? currentLog.workoutExercise.templateSlotId
            ?? libraryWorkout?.templateSlotId(forWorkoutExerciseRow: currentLog.workoutExercise.id)

        let matchingSessions = completedSessions.filter {
            belongs($0, library: libraryWorkout, sessionWorkoutId: session.workout.id)
        }
        guard let latest = matchingSessions.max(by: {
            ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast)
        }) else {
            return nil
        }

        guard let historical = matchingLog(
            in: latest,
            workoutExerciseId: currentLog.workoutExercise.id,
            exerciseIndex: exerciseIndex,
            slotId: slotId,
            libraryExerciseCount: libraryWorkout?.exercises.count
        ) else {
            return nil
        }
        guard !historical.loggedSets.isEmpty else { return nil }
        guard let performedId = historical.workoutExercise.exerciseId else { return nil }

        let plannedId = plannedExerciseId(
            library: libraryWorkout,
            workoutExerciseId: currentLog.workoutExercise.id,
            exerciseIndex: exerciseIndex,
            slotId: slotId
        )
        let plannedName = plannedDisplayName(library: libraryWorkout, exerciseId: plannedId)
        let performedName = displayName(for: historical.workoutExercise)
        let wasSwapped = plannedId != nil && performedId != plannedId

        return PriorWorkoutPerformance(
            performedName: performedName,
            plannedName: plannedName,
            wasSwapped: wasSwapped,
            sets: historical.loggedSets.sorted { $0.timestamp < $1.timestamp },
            configurationFields: historical.workoutExercise.configurationFields,
            performedAt: latest.endTime ?? latest.startTime
        )
    }

    private static func displayName(for workoutExercise: WorkoutExercise) -> String {
        let raw = workoutExercise.snapshot?.nameAtTimeOfLog ?? workoutExercise.slotLabel
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Exercise" : name
    }

    private static func plannedDisplayName(library: Workout?, exerciseId: UUID?) -> String? {
        guard let library, let exerciseId else { return nil }
        if let row = library.exercises.first(where: { $0.exerciseId == exerciseId }) {
            return displayName(for: row)
        }
        return nil
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
