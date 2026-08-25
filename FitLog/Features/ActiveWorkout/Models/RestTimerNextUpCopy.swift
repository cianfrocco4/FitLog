//
//  RestTimerNextUpCopy.swift
//  FitLog
//
//  Lock Screen / notification copy while rest is counting down.
//

import Foundation

enum RestTimerNextUpCopy {
    static let defaultHeadline = "Rest between sets"
    static let defaultNotificationBody = "Time for the next set"

    static func headline(for target: ActiveWorkoutNextUp.Target) -> String {
        switch target {
        case .sameExercise(let name), .nextExercise(let name):
            return "Rest — next: \(name)"
        case .readyToFinish:
            return "Rest — then finish"
        case .unknown:
            return defaultHeadline
        }
    }

    static func notificationBody(for target: ActiveWorkoutNextUp.Target) -> String {
        switch target {
        case .sameExercise(let name):
            return "Time for your next \(name) set"
        case .nextExercise(let name):
            return "Next up: \(name)"
        case .readyToFinish:
            return "Last rest — finish when you're ready"
        case .unknown:
            return defaultNotificationBody
        }
    }
}
