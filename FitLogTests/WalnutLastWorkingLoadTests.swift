//
//  WalnutLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WalnutLastWorkingLoadTests {
    @Test func strengthCaptionUsesNewestWorkingSetAndSkipsWarmup() {
        let exerciseId = UUID()
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let newer = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        let caption = WalnutLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")
        #expect(
            WalnutLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [older, newer],
                displayUnit: .pounds
            ) == 185
        )
    }

    @Test func cardioCaptionUsesNewestDurationAndSkipsIntervalRest() {
        let exerciseId = UUID()
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .manual)
                )
            ]
        )
        let newer = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .intervalRest,
                    cardioMetrics: CardioMetrics(durationSec: 30, source: .timer)
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )

        #expect(
            WalnutLastWorkingLoad.caption(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == "Last 45:00"
        )
        #expect(
            WalnutLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [newer, older]
            ) == 45 * 60
        )
        #expect(
            WalnutLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            WalnutLastWorkingLoad.lastCardioDurationCaption(from: [newer, older]) == "Last 45:00"
        )
    }

    @Test func excludingSessionIdFallsBackToOlderCompletedSession() {
        let exerciseId = UUID()
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let justFinished = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        #expect(
            WalnutLastWorkingLoad.caption(
                for: exerciseId,
                from: [older, justFinished],
                displayUnit: .pounds,
                excludingSessionId: justFinished.id
            ) == "Last 135 lb × 8 reps"
        )
        #expect(
            WalnutLastWorkingLoad.lastCardioDurationCaption(
                from: [older, justFinished],
                excludingSessionId: justFinished.id
            ) == nil
        )
    }

    @Test func inProgressSessionIsIgnored() {
        let exerciseId = UUID()
        let open = session(
            endedAt: nil,
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 225,
                    reps: 5,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let done = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        #expect(
            WalnutLastWorkingLoad.caption(
                for: exerciseId,
                from: [open, done],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func muscleGroupCaptionUsesNewestMatchingExerciseAndSkipsWarmup() {
        let bench = UUID()
        let row = UUID()
        let muscles: [UUID: [MuscleGroup]] = [
            bench: [.chest],
            row: [.lats]
        ]
        let olderChest = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: bench,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let newerChest = session(
            endedAt: Date(),
            exerciseId: bench,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let back = session(
            endedAt: Date().addingTimeInterval(-3_600),
            exerciseId: row,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 200,
                    reps: 6,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        #expect(
            WalnutLastWorkingLoad.caption(
                forMuscleGroupName: MuscleGroup.chest.rawValue,
                from: [olderChest, newerChest, back],
                musclesByExerciseId: muscles,
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            WalnutLastWorkingLoad.caption(
                forMuscleGroupName: MuscleGroup.lats.rawValue,
                from: [olderChest, newerChest, back],
                musclesByExerciseId: muscles,
                displayUnit: .pounds
            ) == "Last 200 lb × 6 reps"
        )
        #expect(
            WalnutLastWorkingLoad.caption(
                forMuscleGroupName: MuscleGroup.quads.rawValue,
                from: [olderChest, newerChest, back],
                musclesByExerciseId: muscles,
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func muscleGroupOtherMatchesExercisesWithNoTargetedMuscles() {
        let uncategorized = UUID()
        let muscles: [UUID: [MuscleGroup]] = [uncategorized: []]
        let logged = session(
            endedAt: Date(),
            exerciseId: uncategorized,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 50,
                    reps: 12,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        #expect(
            WalnutLastWorkingLoad.caption(
                forMuscleGroupName: MuscleGroup.other.rawValue,
                from: [logged],
                musclesByExerciseId: muscles,
                displayUnit: .pounds
            ) == "Last 50 lb × 12 reps"
        )
        #expect(
            WalnutLastWorkingLoad.caption(
                forMuscleGroupName: MuscleGroup.chest.rawValue,
                from: [logged],
                musclesByExerciseId: muscles,
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func newestCompletedCaptionFromLogsNewestFirstSkipsWarmupThenCardio() {
        let bench = UUID()
        let run = UUID()
        let warmupOnly = session(
            endedAt: Date(),
            exerciseId: bench,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                )
            ]
        )
        let cardio = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: run,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )
        let logs = (warmupOnly.exerciseLogs) + (cardio.exerciseLogs)
        #expect(
            WalnutLastWorkingLoad.newestCompletedCaption(
                fromLogsNewestFirst: logs,
                displayUnit: .pounds
            ) == "Last 45:00"
        )
    }

    @Test func workoutCaptionUsesFirstExerciseWithHistory() {
        let bench = UUID()
        let logged = session(
            endedAt: Date(),
            exerciseId: bench,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let emptyRow = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Unknown")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let benchRow = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: bench, nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let workout = Workout(id: UUID(), name: "Push", exercises: [emptyRow, benchRow])
        #expect(
            WalnutLastWorkingLoad.caption(
                for: workout,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func captionsByExerciseIdKeepsNewestPerExercise() {
        let bench = UUID()
        let row = UUID()
        let olderBench = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: bench,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let newer = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Mixed", exercises: []),
            startTime: Date().addingTimeInterval(-3_600),
            endTime: Date(),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: WorkoutExercise(
                        id: UUID(),
                        resolution: .concrete(ExerciseSnapshot(exerciseId: bench, nameAtTimeOfLog: "Bench")),
                        defaultRestTime: 90,
                        recommendedSets: 3,
                        recommendedReps: "8"
                    ),
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: WorkoutExercise(
                        id: UUID(),
                        resolution: .concrete(ExerciseSnapshot(exerciseId: row, nameAtTimeOfLog: "Row")),
                        defaultRestTime: 90,
                        recommendedSets: 3,
                        recommendedReps: "8"
                    ),
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 200,
                            reps: 6,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )

        let captions = WalnutLastWorkingLoad.captionsByExerciseId(
            from: [olderBench, newer],
            displayUnit: .pounds
        )
        #expect(captions[bench] == "Last 185 lb × 8 reps")
        #expect(captions[row] == "Last 200 lb × 6 reps")
    }

    private func session(
        endedAt: Date?,
        workoutId: UUID = UUID(),
        exerciseId: UUID,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Move")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let start = (endedAt ?? Date()).addingTimeInterval(-3_600)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: workoutId, name: "Test", exercises: [row]),
            startTime: start,
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)]
        )
    }
}
