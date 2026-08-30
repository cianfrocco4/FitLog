//
//  HistoryStartFreshWorkout.swift
//  FitLog
//
//  Start a new session from a finished History workout (not resume logged sets).
//

import Foundation

enum HistoryStartFreshWorkout {
    /// Library workout when the finished session still points at one; otherwise the session snapshot.
    static func sourceWorkout(session: WorkoutSession, library: [Workout]) -> Workout? {
        if let id = session.sessionPlanOrigin?.libraryWorkoutId,
           let found = library.first(where: { $0.id == id }),
           !found.exercises.isEmpty {
            return found
        }
        return session.workout.exercises.isEmpty ? nil : session.workout
    }

    /// Starts a **new** session and leaves the finished History entry intact.
    @MainActor
    static func start(
        from session: WorkoutSession,
        dataVM: DataManager,
        currentVM: CurrentWorkoutSessionViewModel,
        openCurrentWorkoutSheet: (() -> Void)?,
        setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
    ) {
        guard let source = sourceWorkout(session: session, library: dataVM.userWorkouts) else { return }
        let toStart = source.hasFlexibleSlots ? dataVM.sessionInstance(from: source) : source
        let origin: WorkoutPlanRef? = {
            if let id = session.sessionPlanOrigin?.libraryWorkoutId, dataVM.workout(id: id) != nil {
                return .workout(id)
            }
            if dataVM.workout(id: source.id) != nil {
                return .workout(source.id)
            }
            return session.sessionPlanOrigin
        }()
        currentVM.startWorkoutResolvingConflict(toStart, sessionPlanOrigin: origin) {
            setPendingReplace($0)
        }
        if currentVM.isInProgress {
            openCurrentWorkoutSheet?()
        }
    }
}
