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
