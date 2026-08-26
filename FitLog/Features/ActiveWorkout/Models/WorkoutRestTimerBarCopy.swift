//
//  WorkoutRestTimerBarCopy.swift
//  FitLog
//
//  In-app rest strip: name the next set instead of only showing swipe instructions.
//

import Foundation

enum WorkoutRestTimerBarCopy {
    static func restCountdownLabel(seconds: Int) -> String {
        "Rest \(max(0, seconds))s"
    }

    /// Subtitle under the Rest heading. Falls back to the swipe hint when next-up is unknown.
    static func subtitle(for target: ActiveWorkoutNextUp.Target) -> String {
        namedSubtitle(for: target) ?? "Swipe left or right to add or subtract 15 seconds"
    }

    /// Home / compact surfaces skip the swipe hint.
    static func namedSubtitle(for target: ActiveWorkoutNextUp.Target) -> String? {
        switch target {
        case .sameExercise(let name):
            return "Next set: \(name)"
        case .nextExercise(let name):
            return "Up next: \(name)"
        case .readyToFinish:
            return "Then finish"
        case .unknown:
            return nil
        }
    }
}
