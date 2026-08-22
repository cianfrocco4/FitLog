//
//  HistorySessionHelpers.swift
//  FitLog
//

import SwiftUI

func completedSessionIsSameCalendarDay(
    _ session: WorkoutSession,
    as reference: Date = Date(),
    calendar: Calendar = .current
) -> Bool {
    guard let end = session.endTime else { return false }
    return calendar.isDate(end, inSameDayAs: reference)
}

@MainActor
func startAgainFromCompletedSession(
    _ session: WorkoutSession,
    currentVM: CurrentWorkoutSessionViewModel,
    openCurrentWorkoutSheet: (() -> Void)?,
    setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
) {
    currentVM.startWorkoutResumingFromCompleted(session) {
        setPendingReplace($0)
    }
    if currentVM.isInProgress {
        openCurrentWorkoutSheet?()
    }
}

/// Library workout to start fresh from a finished session (not resume logged sets).
enum HistoryRepeatWorkout {
    static func sourceWorkout(session: WorkoutSession, library: [Workout]) -> Workout? {
        if let id = session.sessionPlanOrigin?.libraryWorkoutId,
           let found = library.first(where: { $0.id == id }),
           !found.exercises.isEmpty {
            return found
        }
        return session.workout.exercises.isEmpty ? nil : session.workout
    }
}

/// Starts a **new** session from the library (or the finished workout), leaving History intact.
@MainActor
func startFreshWorkoutFromCompletedSession(
    _ session: WorkoutSession,
    dataVM: DataManager,
    currentVM: CurrentWorkoutSessionViewModel,
    openCurrentWorkoutSheet: (() -> Void)?,
    setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
) {
    guard let source = HistoryRepeatWorkout.sourceWorkout(
        session: session,
        library: dataVM.userWorkouts
    ) else { return }
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

@MainActor
func fitlogDeleteCompletedSessionWithUndo(
    _ session: WorkoutSession,
    dataVM: DataManager,
    undoManager: UndoManager?
) {
    let snapshot = session
    guard dataVM.deleteCompletedSession(id: session.id) else { return }
    guard let um = undoManager else { return }
    let dm = dataVM
    um.registerUndo(withTarget: um) { _ in
        _ = dm.restoreCompletedSession(snapshot)
    }
    um.setActionName("Delete Workout")
}

func historySessionPRBadgeLabel(_ kind: PersonalRecordEvent.Kind) -> String {
    switch kind {
    case .maxWeight: return "Wt PR"
    case .estimatedOneRM: return "1RM PR"
    case .maxVolumeSet: return "Vol PR"
    case .maxDistance: return "Dist PR"
    case .bestPace: return "Pace PR"
    case .longestDuration: return "Time PR"
    case .maxCalories: return "Cal PR"
    }
}
