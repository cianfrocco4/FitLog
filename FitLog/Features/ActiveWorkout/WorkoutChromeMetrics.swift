//
//  WorkoutChromeMetrics.swift
//  FitLog
//
//  Measured heights for active-workout chrome (collapsed bar, etc.).
//

import SwiftUI

@Observable
final class WorkoutChromeMetrics {
    /// Measured height of `CurrentWorkoutCollapsedBar`; safe fallback before first layout.
    var collapsedBarHeight: CGFloat = 150
}

private struct WorkoutChromeMetricsKey: EnvironmentKey {
    static let defaultValue = WorkoutChromeMetrics()
}

extension EnvironmentValues {
    var workoutChromeMetrics: WorkoutChromeMetrics {
        get { self[WorkoutChromeMetricsKey.self] }
        set { self[WorkoutChromeMetricsKey.self] = newValue }
    }
}
