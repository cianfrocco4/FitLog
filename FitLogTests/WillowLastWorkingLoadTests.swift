//
//  WillowLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WillowLastWorkingLoadTests {
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
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 6,
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        let caption = WillowLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")

        let fill = WillowLastWorkingLoad.lastStrengthFill(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(fill?.workingSetCount == 2)
        #expect(fill?.reps == 8)
        #expect(fill?.restSeconds == 120)
        #expect(fill?.caption == "Last 185 lb × 8 reps")
    }

    @Test func applyingLastStrengthFillsSetsRepsAndRest() {
        let fill = WillowLastWorkingLoad.LastStrengthFill(
            workingSetCount: 4,
            reps: 6,
            restSeconds: 150,
            caption: "Last 185 lb × 6 reps"
        )
        let original = SplitBuilderEditableSlot(
            label: "Bench",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8-12",
            restSeconds: 90
        )
        let updated = WillowLastWorkingLoad.applying(fill, to: original)
        #expect(updated.sets == 4)
        #expect(updated.reps == "6")
        #expect(updated.restSeconds == 150)
        #expect(updated.label == "Bench")
        #expect(WillowLastWorkingLoad.slotMatchesLastStrength(updated, fill: fill))
        #expect(!WillowLastWorkingLoad.slotMatchesLastStrength(original, fill: fill))

        let nilRest = SplitBuilderEditableSlot(
            label: "Bench",
            targetMuscleNames: ["Chest"],
            sets: 4,
            reps: "6"
        )
        let fillDefaultRest = WillowLastWorkingLoad.LastStrengthFill(
            workingSetCount: 4,
            reps: 6,
            restSeconds: 90,
            caption: "Last 185 lb × 6 reps"
        )
        #expect(WillowLastWorkingLoad.slotMatchesLastStrength(nilRest, fill: fillDefaultRest))
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

        let caption = WillowLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            WillowLastWorkingLoad.lastStrengthFill(
                for: exerciseId,
                from: [older, newer],
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
            WillowLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func workoutCaptionPrefersMatchingSessionThenExerciseHistory() {
        let benchId = UUID()
        let workoutId = UUID()
        let row = workoutRow(exerciseId: benchId)
        let library = Workout(id: workoutId, name: "Push A", exercises: [row])
        let matching = WorkoutSession(
            id: UUID(),
            workout: library,
            startTime: Date().addingTimeInterval(-3_600),
            endTime: Date(),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: row,
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
                )
            ]
        )
        let otherWorkout = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Other", exercises: [row]),
            startTime: Date().addingTimeInterval(-7_200),
            endTime: Date().addingTimeInterval(-3_600),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: row,
                    loggedSets: [
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
            ]
        )

        #expect(
            WillowLastWorkingLoad.caption(
                forWorkout: library,
                from: [matching, otherWorkout],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )

        let unmatchedLibrary = Workout(id: UUID(), name: "Push A copy", exercises: [row])
        #expect(
            WillowLastWorkingLoad.caption(
                forWorkout: unmatchedLibrary,
                from: [otherWorkout],
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
        let map = WillowLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
        #expect(map[bench] == "Last 185 lb × 8 reps")
        #expect(map[run] == "Last 30:00")
    }

    private func workoutRow(exerciseId: UUID) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Move")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
    }

    private func session(
        endedAt: Date?,
        exerciseId: UUID,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let row = workoutRow(exerciseId: exerciseId)
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
