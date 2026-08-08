//
//  CollapsedWorkoutBarAccessibilityTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct CollapsedWorkoutBarAccessibilityTests {

    @Test func openLoggingLabel_includesWorkoutExerciseAndSets() {
        let label = CollapsedWorkoutBarAccessibility.openLoggingLabel(
            workoutName: "Push Day",
            exerciseName: "Bench Press",
            setProgress: "2/4 sets",
            remainingRestSeconds: 0
        )
        #expect(label == "Open workout logging, Push Day, Now: Bench Press, 2/4 sets")
    }

    @Test func openLoggingLabel_includesRestWhenActive() {
        let label = CollapsedWorkoutBarAccessibility.openLoggingLabel(
            workoutName: "Legs",
            exerciseName: "Squat",
            setProgress: "1/3 sets",
            remainingRestSeconds: 45
        )
        #expect(label == "Open workout logging, Legs, Now: Squat, 1/3 sets, 45 seconds rest remaining")
    }

    @Test func openLoggingLabel_usesSingularSecond() {
        let label = CollapsedWorkoutBarAccessibility.openLoggingLabel(
            workoutName: nil,
            exerciseName: "Curl",
            setProgress: nil,
            remainingRestSeconds: 1
        )
        #expect(label == "Open workout logging, Now: Curl, 1 second rest remaining")
    }

    @Test func openLoggingLabel_omitsBlankParts() {
        let label = CollapsedWorkoutBarAccessibility.openLoggingLabel(
            workoutName: "  ",
            exerciseName: nil,
            setProgress: "",
            remainingRestSeconds: 0
        )
        #expect(label == "Open workout logging")
    }
}
