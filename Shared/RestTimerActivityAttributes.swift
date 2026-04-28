//
//  RestTimerActivityAttributes.swift
//  FitLog
//
//  Shared between the app and the Live Activity widget extension (ActivityKit type identity).
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct RestTimerActivityAttributes: ActivityAttributes {
    /// Workout name shown on the Lock Screen / Dynamic Island.
    var workoutName: String

    struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var headline: String
    }
}
#endif
