//
//  HomeActiveWorkoutProgressTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct HomeActiveWorkoutProgressTests {
    @Test func countableExercises_excludeOpenPlaceholders() {
        let logs = [workingLog(sets: 0, recommended: 3), placeholderLog()]
        #expect(HomeActiveWorkoutProgress.countableExerciseCount(in: logs) == 1)
    }

    @Test func completedCount_usesLoggedSetsAgainstRecommended() {
        let logs = [
            workingLog(sets: 3, recommended: 3),
            workingLog(sets: 1, recommended: 3),
            workingLog(sets: 0, recommended: 3)
        ]
        #expect(HomeActiveWorkoutProgress.completedExerciseCount(in: logs) == 1)
        #expect(
            HomeActiveWorkoutProgress.progressFraction(completed: 1, total: 3)
                == Double(1) / Double(3)
        )
    }

    @Test func completedCount_ignoresManualCompletedIdsSemantics() {
        // Progress is set-based; an exercise with zero logged sets is incomplete
        // even if a caller might track completion ids separately.
        let logs = [workingLog(sets: 0, recommended: 3)]
        #expect(HomeActiveWorkoutProgress.completedExerciseCount(in: logs) == 0)
    }

    private func workingLog(sets: Int, recommended: Int) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let logged: [LoggedSet] = (0..<sets).map { _ in
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: .working
            )
        }
        return ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: recommended,
                recommendedReps: "8"
            ),
            loggedSets: logged
        )
    }

    private func placeholderLog() -> ExerciseLog {
        ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .flexible(
                    SlotBlueprint(
                        id: UUID(),
                        label: "Open",
                        targetedMuscles: [.chest]
                    )
                ),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: []
        )
    }
}
