//
//  WorkoutFocusedExerciseNavAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct WorkoutFocusedExerciseNavAccessibilityTests {

    @Test func currentExerciseLabel_combinesTitleAndPosition() {
        #expect(
            WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                exerciseTitle: "Bench Press",
                positionLabel: "Exercise 2 of 5"
            ) == "Bench Press, Exercise 2 of 5"
        )
    }

    @Test func currentExerciseLabel_fallsBackWhenPartsMissing() {
        #expect(
            WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                exerciseTitle: "  ",
                positionLabel: "Exercise 1 of 3"
            ) == "Exercise 1 of 3"
        )
        #expect(
            WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                exerciseTitle: "Squat",
                positionLabel: "   "
            ) == "Squat"
        )
        #expect(
            WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                exerciseTitle: "",
                positionLabel: ""
            ) == "Current exercise"
        )
    }

    @Test func previousAndNextHints_reflectAvailability() {
        #expect(
            WorkoutFocusedExerciseNavAccessibility.previousHint(canGoPrevious: true)
                == "Moves to the previous exercise in this workout"
        )
        #expect(
            WorkoutFocusedExerciseNavAccessibility.previousHint(canGoPrevious: false)
                == "Already on the first exercise"
        )
        #expect(
            WorkoutFocusedExerciseNavAccessibility.nextHint(canGoNext: true)
                == "Moves to the next exercise in this workout"
        )
        #expect(
            WorkoutFocusedExerciseNavAccessibility.nextHint(canGoNext: false)
                == "Already on the last exercise"
        )
    }
}
