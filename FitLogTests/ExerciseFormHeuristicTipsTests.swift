//
//  ExerciseFormHeuristicTipsTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ExerciseFormHeuristicTipsTests {

    @Test func chestPressTips_requireChestMuscleGroup() {
        let chestPress = Exercise(
            id: UUID(),
            name: "Incline Dumbbell Press",
            description: "",
            targetedMuscles: [.chest]
        )
        let shoulderPress = Exercise(
            id: UUID(),
            name: "Overhead Barbell Press",
            description: "",
            targetedMuscles: [.frontDelts, .sideDelts]
        )

        let chestTips = ExerciseFormHeuristicTips.tips(for: chestPress)
        let shoulderTips = ExerciseFormHeuristicTips.tips(for: shoulderPress)

        #expect(chestTips.first?.localizedCaseInsensitiveContains("shoulder blades") == true)
        #expect(shoulderTips.first?.localizedCaseInsensitiveContains("shoulder blades") == false)
    }

    @Test func benchOnlyName_stillReturnsChestTipsWhenMuscleTagged() {
        let exercise = Exercise(
            id: UUID(),
            name: "Close-Grip Bench",
            description: "",
            targetedMuscles: [.chest, .triceps]
        )

        let tips = ExerciseFormHeuristicTips.tips(for: exercise)
        #expect(tips.first?.localizedCaseInsensitiveContains("shoulder blades") == true)
    }
}
