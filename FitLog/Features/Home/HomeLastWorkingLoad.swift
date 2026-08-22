//
//  HomeLastWorkingLoad.swift
//  FitLog
//
//  Last working set from a completed session, for Home / History “where I left off”.
//

import Foundation

enum HomeLastWorkingLoad {
    struct Snapshot: Equatable, Hashable {
        let weightPounds: Double
        let reps: Int
        let exerciseName: String
    }

    /// Most recent working set in session order (last exercise that has a load PR set).
    static func snapshot(from session: WorkoutSession) -> Snapshot? {
        var latest: (set: LoggedSet, name: String, order: Int)?
        for (index, log) in session.exerciseLogs.enumerated() {
            let name = fallbackExerciseName(from: log.workoutExercise)
            for set in log.loggedSets where set.countsTowardLoadPRMetrics && set.weight > 0 {
                if let current = latest {
                    if set.timestamp > current.set.timestamp
                        || (set.timestamp == current.set.timestamp && index >= current.order) {
                        latest = (set, name, index)
                    }
                } else {
                    latest = (set, name, index)
                }
            }
        }
        guard let latest else { return nil }
        return Snapshot(
            weightPounds: latest.set.weight,
            reps: latest.set.reps,
            exerciseName: latest.name
        )
    }

    static func snapshot(
        forLibraryWorkoutId libraryId: UUID,
        sessions: [WorkoutSession]
    ) -> Snapshot? {
        guard let session = lastCompletedSession(forLibraryWorkoutId: libraryId, sessions: sessions) else {
            return nil
        }
        return snapshot(from: session)
    }

    static func lastCompletedSession(
        forLibraryWorkoutId libraryId: UUID,
        sessions: [WorkoutSession]
    ) -> WorkoutSession? {
        sessions
            .filter { session in
                guard session.isCompleted else { return false }
                if session.sessionPlanOrigin?.libraryWorkoutId == libraryId { return true }
                return session.workout.id == libraryId
            }
            .max { lhs, rhs in
                (lhs.endTime ?? lhs.startTime) < (rhs.endTime ?? rhs.startTime)
            }
    }

    static func fallbackExerciseName(from workoutExercise: WorkoutExercise) -> String {
        if let snap = workoutExercise.snapshot {
            let name = snap.nameAtTimeOfLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        let label = workoutExercise.slotLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "Exercise" : label
    }
}
