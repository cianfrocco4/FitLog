//
//  AlderLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AlderLastWorkingLoadTests {
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

        let caption = AlderLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")
        #expect(
            AlderLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [older, newer],
                displayUnit: .pounds
            ) == 185
        )
    }

    @Test func kilogramsCaptionConvertsStoredPounds() {
        let exerciseId = UUID()
        let logged = session(
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
        let kg = WeightStoreConversion.displayValue(storedPounds: 185, unit: .kilograms)
        let expected = "Last \(WeightStoreConversion.formatDisplay(kg)) kg × 8 reps"
        #expect(
            AlderLastWorkingLoad.caption(
                for: exerciseId,
                from: [logged],
                displayUnit: .kilograms
            ) == expected
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
            AlderLastWorkingLoad.caption(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == "Last 45:00"
        )
        #expect(
            AlderLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
                from: [newer, older]
            ) == 45 * 60
        )
        #expect(
            AlderLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [newer, older],
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            AlderLastWorkingLoad.lastCardioDurationCaption(from: [newer, older]) == "Last 45:00"
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
                    reps: 5,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        #expect(
            AlderLastWorkingLoad.caption(
                for: exerciseId,
                from: [older, justFinished],
                displayUnit: .pounds,
                excludingSessionId: justFinished.id
            ) == "Last 135 lb × 10 reps"
        )
        #expect(
            AlderLastWorkingLoad.lastWorkingDisplayWeight(
                for: exerciseId,
                from: [older, justFinished],
                displayUnit: .pounds,
                excludingSessionId: justFinished.id
            ) == 135
        )
        #expect(
            AlderLastWorkingLoad.lastCardioDurationSec(
                for: exerciseId,
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
            AlderLastWorkingLoad.caption(
                for: exerciseId,
                from: [open, done],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
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
            AlderLastWorkingLoad.caption(
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

        let captions = AlderLastWorkingLoad.captionsByExerciseId(
            from: [olderBench, newer],
            displayUnit: .pounds
        )
        #expect(captions[bench] == "Last 185 lb × 8 reps")
        #expect(captions[row] == "Last 200 lb × 6 reps")
    }

    @Test func newestCompletedCaptionPrefersNewestSessionWorkingSet() {
        let bench = UUID()
        let run = UUID()
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

        #expect(
            AlderLastWorkingLoad.newestCompletedCaption(
                from: [cardio, strength],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func dayCaptionUsesOverrideIdThenSuggestedName() {
        let bench = UUID()
        let library = [
            Exercise(
                id: bench,
                name: "Bench Press",
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
        let unknownFirst = SplitBuilderEditableSlot(
            label: "Unknown",
            targetMuscleNames: [],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Not In Library"
        )
        let named = SplitBuilderEditableSlot(
            label: "Chest",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Bench Press"
        )
        let overridden = SplitBuilderEditableSlot(
            label: "Chest",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Wrong Name",
            suggestedExerciseOverrideId: bench
        )
        let dayByName = SplitBuilderEditableDay(
            name: "Push",
            focus: "",
            slots: [unknownFirst, named]
        )
        let dayByOverride = SplitBuilderEditableDay(
            name: "Push",
            focus: "",
            slots: [overridden]
        )

        #expect(
            AlderLastWorkingLoad.resolvedExerciseId(for: named, library: library) == bench
        )
        #expect(
            AlderLastWorkingLoad.resolvedExerciseId(for: overridden, library: library) == bench
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forDay: dayByName,
                from: [logged],
                library: library,
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forDay: dayByOverride,
                from: [logged],
                library: library,
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forDays: [dayByName],
                from: [logged],
                library: library,
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func dayCaptionReturnsNilWhenSlotsHaveNoHistory() {
        let library = [
            Exercise(
                id: UUID(),
                name: "Bench Press",
                description: "",
                targetedMuscles: [.chest]
            )
        ]
        let day = SplitBuilderEditableDay(
            name: "Push",
            focus: "",
            slots: [
                SplitBuilderEditableSlot(
                    label: "Chest",
                    targetMuscleNames: ["Chest"],
                    sets: 3,
                    reps: "8",
                    suggestedExerciseName: "Bench Press"
                )
            ]
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forDay: day,
                from: [],
                library: library,
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func blockCaptionUsesCurrentBlockNotLaterBlocks() {
        let squat = UUID()
        let bench = UUID()
        let library = [
            Exercise(id: squat, name: "Back Squat", description: "", targetedMuscles: [.quads]),
            Exercise(id: bench, name: "Bench Press", description: "", targetedMuscles: [.chest])
        ]
        let squatLogged = session(
            endedAt: Date(),
            exerciseId: squat,
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
        let legsBlock = ProgramBlock(
            name: "Legs",
            focus: BlockFocus(kind: .hypertrophy),
            durationWeeks: 4,
            weeklyTemplates: [
                BlockWeeklyTemplate(
                    dayName: "Squat day",
                    focus: "Legs",
                    slots: [
                        SplitBuilderEditableSlot(
                            label: "Squat",
                            targetMuscleNames: ["Quads"],
                            sets: 4,
                            reps: "5",
                            suggestedExerciseName: "Back Squat"
                        )
                    ]
                )
            ]
        )
        let pushBlock = ProgramBlock(
            name: "Push",
            focus: BlockFocus(kind: .hypertrophy),
            durationWeeks: 4,
            weeklyTemplates: [
                BlockWeeklyTemplate(
                    dayName: "Push",
                    focus: "Chest",
                    slots: [
                        SplitBuilderEditableSlot(
                            label: "Chest",
                            targetMuscleNames: ["Chest"],
                            sets: 3,
                            reps: "8",
                            suggestedExerciseName: "Bench Press"
                        )
                    ]
                )
            ]
        )

        #expect(
            AlderLastWorkingLoad.caption(
                forBlock: legsBlock,
                from: [squatLogged],
                library: library,
                displayUnit: .pounds
            ) == "Last 225 lb × 5 reps"
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forBlock: pushBlock,
                from: [squatLogged],
                library: library,
                displayUnit: .pounds
            ) == nil
        )
        #expect(
            AlderLastWorkingLoad.caption(
                forProgram: DynamicProgram(
                    name: "Split",
                    blocks: [pushBlock, legsBlock],
                    defaultSessionsPerWeek: 4
                ),
                from: [squatLogged],
                library: library,
                displayUnit: .pounds
            ) == "Last 225 lb × 5 reps"
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
