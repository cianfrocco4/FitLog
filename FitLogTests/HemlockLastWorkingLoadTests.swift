//
//  HemlockLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct HemlockLastWorkingLoadTests {
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

        let caption = HemlockLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")
    }

    @Test func lastWorkingDisplayWeightSkipsWarmupAndUsesNewestSession() {
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

        let pounds = HemlockLastWorkingLoad.lastWorkingDisplayWeight(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(pounds == 185)
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

        let caption = HemlockLastWorkingLoad.caption(
            for: exerciseId,
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            HemlockLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [newer, older]
            ) == 45 * 60
        )
        #expect(
            HemlockLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
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
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            HemlockLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            HemlockLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [open]
            ) == nil
        )
    }

    @Test func workoutExerciseCaptionUsesResolvedExerciseId() {
        let exerciseId = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let logged = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 5,
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            HemlockLastWorkingLoad.caption(
                for: row,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 5 reps"
        )
    }

    @Test func exerciseLogCaptionMatchesWorkoutExercise() {
        let exerciseId = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Row")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: row,
            loggedSets: []
        )
        let logged = session(
            endedAt: Date(),
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
        #expect(
            HemlockLastWorkingLoad.caption(
                for: log,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 135 lb × 10 reps"
        )
    }

    @Test func captionsByExerciseIdIndexesMultipleExercises() {
        let bench = UUID()
        let run = UUID()
        let sessions = [
            session(
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
            ),
            session(
                endedAt: Date().addingTimeInterval(-3_600),
                exerciseId: run,
                sets: [
                    LoggedSet(
                        id: UUID(),
                        weight: 0,
                        reps: 0,
                        restTime: 0,
                        timestamp: Date(),
                        setType: .steadyState,
                        cardioMetrics: CardioMetrics(durationSec: 30 * 60, source: .manual)
                    )
                ]
            )
        ]
        let map = HemlockLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
        #expect(map[bench] == "Last 185 lb × 8 reps")
        #expect(map[run] == "Last 30:00")
    }

    @Test func kilogramsCaptionConvertsStoredPounds() {
        let exerciseId = UUID()
        let logged = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 220.462,
                    reps: 5,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let caption = HemlockLastWorkingLoad.caption(
            for: exerciseId,
            from: [logged],
            displayUnit: .kilograms
        )
        #expect(caption?.contains("kg") == true)
        #expect(caption?.hasPrefix("Last ") == true)

        let kg = HemlockLastWorkingLoad.lastWorkingDisplayWeight(
            for: exerciseId,
            from: [logged],
            displayUnit: .kilograms
        )
        #expect(kg != nil)
        if let kg {
            #expect(abs(kg - 100) < 0.2)
        }
    }

    @Test func openSlotWithoutExerciseIdHasNoCaption() {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    label: "Horizontal press",
                    targetedMuscles: [.chest]
                )
            ),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let logged = session(
            endedAt: Date(),
            exerciseId: UUID(),
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 5,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            HemlockLastWorkingLoad.caption(
                for: row,
                from: [logged],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            HemlockLastWorkingLoad.lastCardioDurationSec(
                for: UUID(),
                from: [logged]
            ) == nil
        )
    }

    private func session(
        endedAt: Date?,
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
            workout: Workout(id: UUID(), name: "Test", exercises: [row]),
            startTime: start,
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)]
        )
    }
}
