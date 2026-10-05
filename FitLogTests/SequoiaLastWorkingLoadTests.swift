//
//  SequoiaLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct SequoiaLastWorkingLoadTests {
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

        let caption = SequoiaLastWorkingLoad.caption(
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

        let pounds = SequoiaLastWorkingLoad.lastWorkingDisplayWeight(
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

        let caption = SequoiaLastWorkingLoad.caption(
            for: exerciseId,
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            SequoiaLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [newer, older]
            ) == 45 * 60
        )
        #expect(
            SequoiaLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            SequoiaLastWorkingLoad.lastCardioDurationCaption(from: [newer, older]) == "Last 45:00"
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
            SequoiaLastWorkingLoad.caption(
                for: exerciseId,
                from: [older, justFinished],
                displayUnit: .pounds,
                excludingSessionId: justFinished.id
            ) == "Last 135 lb × 10 reps"
        )
        #expect(
            SequoiaLastWorkingLoad.lastCardioDurationCaption(
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
            SequoiaLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            SequoiaLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [open]
            ) == nil
        )
        #expect(SequoiaLastWorkingLoad.lastCardioDurationCaption(from: [open]) == nil)
        #expect(SequoiaLastWorkingLoad.newestCompletedCaption(from: [open], displayUnit: .pounds) == nil)
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
            SequoiaLastWorkingLoad.caption(
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
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            SequoiaLastWorkingLoad.caption(
                for: log,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 135 lb × 8 reps"
        )
    }

    @Test func captionsByExerciseIdKeepsNewestPerExercise() {
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
        let byId = SequoiaLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
        #expect(byId[bench] == "Last 185 lb × 8 reps")
        #expect(byId[run] == "Last 30:00")
    }

    @Test func workoutCaptionUsesFirstConcreteExerciseWithHistory() {
        let bench = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: bench, nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let workout = Workout(id: UUID(), name: "Push", exercises: [row])
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
            SequoiaLastWorkingLoad.caption(
                for: workout,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func captionForWorkoutIdUsesThatWorkoutsNewestSession() {
        let pushId = UUID()
        let pullId = UUID()
        let bench = UUID()
        let row = UUID()
        let push = session(
            endedAt: Date().addingTimeInterval(-86_400),
            workoutId: pushId,
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
        let pull = session(
            endedAt: Date(),
            workoutId: pullId,
            exerciseId: row,
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
            SequoiaLastWorkingLoad.caption(
                forWorkoutId: pushId,
                from: [push, pull],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            SequoiaLastWorkingLoad.caption(
                forWorkoutId: pullId,
                from: [push, pull],
                displayUnit: .pounds
            ) == "Last 135 lb × 10 reps"
        )
        #expect(
            SequoiaLastWorkingLoad.newestCompletedCaption(
                from: [push, pull],
                displayUnit: .pounds
            ) == "Last 135 lb × 10 reps"
        )
    }

    @Test func slotCaptionResolvesOverrideIdThenLibraryName() {
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
            SequoiaLastWorkingLoad.caption(
                for: byId,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            SequoiaLastWorkingLoad.caption(
                for: byName,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            SequoiaLastWorkingLoad.caption(
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
            SequoiaLastWorkingLoad.caption(
                for: day,
                library: library,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func programBlockCaptionSkipsWarmUpSlots() {
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
        let block = ProgramBlock(
            name: "Block 1",
            focus: BlockFocus(kind: .hypertrophy, emphasisLabel: "Push"),
            durationWeeks: 4,
            weeklyTemplates: [
                BlockWeeklyTemplate(
                    dayName: "Push",
                    focus: "Chest",
                    slots: [
                        SplitBuilderEditableSlot(
                            label: "Warm-up press",
                            targetMuscleNames: ["Chest"],
                            sets: 2,
                            reps: "12",
                            suggestedExerciseName: "Barbell Bench Press",
                            isWarmUp: true
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
            ]
        )
        #expect(
            SequoiaLastWorkingLoad.caption(
                for: block,
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
            SequoiaLastWorkingLoad.newestCompletedCaption(
                from: [cardio, strength],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
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
