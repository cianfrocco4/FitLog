//
//  BeechLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct BeechLastWorkingLoadTests {
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

        let caption = BeechLastWorkingLoad.caption(
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

        let pounds = BeechLastWorkingLoad.lastWorkingDisplayWeight(
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

        let caption = BeechLastWorkingLoad.caption(
            for: exerciseId,
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            BeechLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [newer, older]
            ) == 45 * 60
        )
        #expect(
            BeechLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            BeechLastWorkingLoad.lastCardioDurationCaption(from: [newer, older]) == "Last 45:00"
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
            BeechLastWorkingLoad.caption(
                for: exerciseId,
                from: [older, justFinished],
                displayUnit: .pounds,
                excludingSessionId: justFinished.id
            ) == "Last 135 lb × 10 reps"
        )
        #expect(
            BeechLastWorkingLoad.lastCardioDurationCaption(
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
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            BeechLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [open]
            ) == nil
        )
        #expect(BeechLastWorkingLoad.lastCardioDurationCaption(from: [open]) == nil)
        #expect(BeechLastWorkingLoad.newestCompletedCaption(from: [open], displayUnit: .pounds) == nil)
    }

    @Test func workoutExerciseCaptionUsesResolvedExerciseId() {
        let exerciseId = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Zone 2")),
            defaultRestTime: 90,
            recommendedSets: 1,
            recommendedReps: "—"
        )
        let logged = session(
            endedAt: Date(),
            exerciseId: exerciseId,
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
        #expect(
            BeechLastWorkingLoad.caption(
                for: row,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 45:00"
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
            BeechLastWorkingLoad.caption(
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
        let map = BeechLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
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
        let caption = BeechLastWorkingLoad.caption(
            for: exerciseId,
            from: [logged],
            displayUnit: .kilograms
        )
        #expect(caption?.contains("kg") == true)
        #expect(caption?.hasPrefix("Last ") == true)

        let kg = BeechLastWorkingLoad.lastWorkingDisplayWeight(
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
            BeechLastWorkingLoad.caption(
                for: row,
                from: [logged],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            BeechLastWorkingLoad.lastCardioDurationSec(
                for: UUID(),
                from: [logged]
            ) == nil
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: Workout(id: UUID(), name: "Open", exercises: [row]),
                from: [logged],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func workoutCaptionUsesFirstConcreteExercise() {
        let bench = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: bench, nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let workout = Workout(id: UUID(), name: "Push A", exercises: [row])
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
        #expect(
            BeechLastWorkingLoad.caption(
                for: workout,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func slotCaptionPrefersOverrideIdThenLibraryName() {
        let bench = UUID()
        let library = [
            Exercise(
                id: bench,
                name: "Barbell Bench Press",
                description: "",
                targetedMuscles: [.chest]
            )
        ]
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
        let byId = SplitBuilderEditableSlot(
            label: "Press",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Something else",
            suggestedExerciseOverrideId: bench
        )
        let byName = SplitBuilderEditableSlot(
            label: "Press",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Barbell Bench Press"
        )
        let unmatched = SplitBuilderEditableSlot(
            label: "Mystery",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Unknown machine"
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: byId,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: byName,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: unmatched,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func templateDayCaptionUsesFirstMatchingSlot() {
        let bench = UUID()
        let library = [
            Exercise(
                id: bench,
                name: "Barbell Bench Press",
                description: "",
                targetedMuscles: [.chest]
            )
        ]
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
        let day = BlockWeeklyTemplate(
            dayName: "Push",
            focus: "Chest",
            slots: [
                SplitBuilderEditableSlot(
                    label: "Mystery",
                    targetMuscleNames: ["Chest"],
                    sets: 3,
                    reps: "8",
                    suggestedExerciseName: "Unknown"
                ),
                SplitBuilderEditableSlot(
                    label: "Press",
                    targetMuscleNames: ["Chest"],
                    sets: 3,
                    reps: "8",
                    suggestedExerciseName: "Barbell Bench Press"
                )
            ]
        )
        #expect(
            BeechLastWorkingLoad.caption(
                for: day,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func newestCompletedCaptionPrefersWorkingSetOverOlderCardio() {
        let bench = UUID()
        let run = UUID()
        let strength = session(
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
        #expect(
            BeechLastWorkingLoad.newestCompletedCaption(
                from: [cardio, strength],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
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
