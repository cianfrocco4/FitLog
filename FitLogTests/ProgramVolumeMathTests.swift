//
//  ProgramVolumeMathTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class ProgramVolumeMathTests: XCTestCase {
    func testPlannedHardSetsExcludesWarmUpAndCardio() {
        let slots = [
            SplitBuilderEditableSlot(
                label: "Warm",
                targetMuscleNames: [],
                sets: 2,
                reps: "10",
                isWarmUp: true
            ),
            SplitBuilderEditableSlot(
                label: "Squat",
                targetMuscleNames: ["quads"],
                sets: 4,
                reps: "5"
            ),
            SplitBuilderEditableSlot(
                label: "Bike",
                targetMuscleNames: [],
                sets: 1,
                reps: "",
                modality: .cardio,
                cardioPrescription: CardioPrescription(targetDurationSec: 600, targetZone: .zone2)
            ),
        ]
        XCTAssertEqual(ProgramVolumeMath.plannedHardSets(in: slots), 4)
        XCTAssertEqual(ProgramVolumeMath.plannedHardSets(in: slots, volumeMultiplier: 0.7), 3)
    }

    func testPlannedWeeklyHardSetsUsesBlockMultiplier() {
        let block = ProgramBlock(
            name: "Deload",
            focus: BlockFocus(kind: .deload, emphasisLabel: ""),
            durationWeeks: 1,
            weeklyTemplates: [
                BlockWeeklyTemplate(
                    dayName: "Full",
                    focus: "",
                    slots: [
                        SplitBuilderEditableSlot(label: "Press", targetMuscleNames: ["chest"], sets: 10, reps: "8"),
                    ]
                ),
            ],
            isDeloadBlock: true,
            volumeMultiplier: 0.7
        )
        XCTAssertEqual(ProgramVolumeMath.plannedWeeklyHardSets(for: block), 7)
    }

    func testActualHardSetsUsesCountsTowardVolumeTotals() {
        let working = LoggedSet(
            id: UUID(),
            weight: 100,
            reps: 5,
            restTime: 90,
            timestamp: Date(),
            setType: .working
        )
        let warmup = LoggedSet(
            id: UUID(),
            weight: 45,
            reps: 8,
            restTime: 60,
            timestamp: Date(),
            setType: .warmup
        )
        let exercise = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "5")
        let log = ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [warmup, working, working])
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push", exercises: [we]),
            startTime: Date(),
            endTime: Date(),
            exerciseLogs: [log],
            activeExerciseIds: [],
            completedExerciseIds: [we.id]
        )
        XCTAssertEqual(ProgramVolumeMath.actualHardSets(in: [session]), 2)
    }
}
