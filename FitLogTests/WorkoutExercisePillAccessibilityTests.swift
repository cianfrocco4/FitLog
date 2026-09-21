//
//  WorkoutExercisePillAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct WorkoutExercisePillAccessibilityTests {
    @Test func pillLabelIncludesLastWorkingLoad() {
        #expect(
            WorkoutExercisePillAccessibility.pillLabel(
                name: "Bench Press",
                done: 1,
                rec: 3,
                isPlaceholder: false,
                letter: nil,
                repGoal: "8",
                lastLoad: "Last 185 lb × 8 reps"
            ) == "Bench Press, 1 of 3 work sets, goal 8 reps, Last 185 lb × 8 reps"
        )
    }

    @Test func pillLabelOmitsEmptyLastLoad() {
        #expect(
            WorkoutExercisePillAccessibility.pillLabel(
                name: "Squat",
                done: 0,
                rec: 3,
                isPlaceholder: false,
                letter: "A",
                repGoal: nil,
                lastLoad: nil
            ) == "Superset A of the round, Squat, 0 of 3 work sets"
        )
    }

    @Test func nextExerciseBannerIncludesLastLoad() {
        #expect(
            WorkoutExercisePillAccessibility.nextExerciseBannerLabel(
                exerciseName: "Incline Press",
                lastLoad: "Last 70 lb × 10 reps"
            ) == "Next: Incline Press. Last 70 lb × 10 reps. Tap to log"
        )
        #expect(
            WorkoutExercisePillAccessibility.nextExerciseBannerLabel(
                exerciseName: "Incline Press",
                lastLoad: nil
            ) == "Next: Incline Press. Tap to log"
        )
    }

    @Test func supersetChipIncludesLastCardioDuration() {
        #expect(
            WorkoutExercisePillAccessibility.supersetChipLabel(
                letter: "B",
                name: "Zone 2",
                lastLoad: "Last 45:00"
            ) == "Superset B, Zone 2, Last 45:00"
        )
    }
}
