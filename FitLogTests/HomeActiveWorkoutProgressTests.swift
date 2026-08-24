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

    @Test func warmupsDoNotAdvanceTheTarget() {
        let log = log(setTypes: [.warmup, .warmup, .working, .working, .working], recommended: 3)
        #expect(log.workingSetCount == 3)
        #expect(log.warmupSetCount == 2)
        #expect(log.meetsRecommendedSets)
        #expect(HomeActiveWorkoutProgress.completedExerciseCount(in: [log]) == 1)
    }

    @Test func warmupsOnly_isNoProgress() {
        let log = log(setTypes: [.warmup, .warmup], recommended: 3)
        #expect(log.workingSetCount == 0)
        #expect(log.meetsRecommendedSets == false)
        #expect(HomeActiveWorkoutProgress.completedExerciseCount(in: [log]) == 0)
    }

    @Test func timedHoldsCountTowardTheTarget() {
        // A plank is a prescribed set even though it contributes no tonnage.
        let log = log(setTypes: [.timed, .timed, .timed], recommended: 3)
        #expect(log.workingSetCount == 3)
        #expect(log.meetsRecommendedSets)
    }

    @Test func failureAndAmrapSetsCountTowardTheTarget() {
        let log = log(setTypes: [.working, .amrap, .failure], recommended: 3)
        #expect(log.workingSetCount == 3)
        #expect(log.meetsRecommendedSets)
    }

    @Test func warmupProgressCopy_keepsWarmupsVisible() {
        #expect(WorkoutSetProgressCopy.warmupMarker(count: 0).isEmpty)
        #expect(WorkoutSetProgressCopy.warmupMarker(count: 1) == "+1 warm-up")
        #expect(WorkoutSetProgressCopy.warmupMarker(count: 3) == "+3 warm-ups")
        #expect(
            WorkoutSetProgressCopy.workSetProgressLabel(done: 1, target: 3, warmups: 2)
                == "1 of 3 work sets, plus 2 warm-up sets"
        )
        #expect(
            WorkoutSetProgressCopy.workSetProgressLabel(done: 2, target: 3, warmups: 0)
                == "2 of 3 work sets"
        )
    }

    private func workingLog(sets: Int, recommended: Int) -> ExerciseLog {
        log(setTypes: Array(repeating: .working, count: sets), recommended: recommended)
    }

    private func log(setTypes: [ExerciseSetType], recommended: Int) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let logged: [LoggedSet] = setTypes.map { type in
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: type
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
