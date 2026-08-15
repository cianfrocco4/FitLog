//
//  WorkoutCompletionNavigation.swift
//  FitLog
//
//  Pure helpers for post-workout dismiss choices (History vs Done / paywall).
//

import Foundation

enum WorkoutCompletionDismissKind: Equatable {
    case done
    case viewInHistory
}

enum WorkoutCompletionNavigation {
    /// Post-workout paywall should only follow a normal Done dismiss — not when
    /// the user explicitly asks to confirm the session in History.
    static func shouldOfferPostWorkoutPaywall(after dismiss: WorkoutCompletionDismissKind) -> Bool {
        switch dismiss {
        case .done:
            return true
        case .viewInHistory:
            return false
        }
    }

    static func viewInHistoryAccessibilityHint(workoutName: String) -> String {
        "Opens \(workoutName) in History"
    }
}
