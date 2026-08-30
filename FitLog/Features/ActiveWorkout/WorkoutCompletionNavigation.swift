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
    case startAgain
}

enum WorkoutCompletionNavigation {
    /// Post-workout paywall should only follow a normal Done dismiss — not when
    /// the user explicitly asks to confirm the session in History or start again.
    static func shouldOfferPostWorkoutPaywall(after dismiss: WorkoutCompletionDismissKind) -> Bool {
        switch dismiss {
        case .done:
            return true
        case .viewInHistory, .startAgain:
            return false
        }
    }

    static func viewInHistoryAccessibilityHint(workoutName: String) -> String {
        "Opens \(workoutName) in History"
    }

    static func startAgainAccessibilityHint(workoutName: String) -> String {
        "Starts a new \(workoutName) session. The finished entry stays in History."
    }
}
