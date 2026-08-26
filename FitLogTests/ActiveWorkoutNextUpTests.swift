//
//  ActiveWorkoutNextUpTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct ActiveWorkoutNextUpTests {
    @Test func sameExercise_whileWorkSetsRemain() {
        let logs = [
            workingLog(name: "Bench Press", sets: 1, recommended: 3),
            workingLog(name: "Row", sets: 0, recommended: 3)
        ]
        let target = ActiveWorkoutNextUp.resolve(
            logs: logs,
            currentIndex: 0,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "" }
        )
        #expect(target == .sameExercise(name: "Bench Press"))
        #expect(
            ActiveWorkoutNextUp.loggedSetProgressNote(target: target, done: 1, recommended: 3)
                == "1 of 3 work sets"
        )
    }

    @Test func nextExercise_afterCurrentMeetsRecommended() {
        let logs = [
            workingLog(name: "Bench Press", sets: 3, recommended: 3),
            workingLog(name: "Row", sets: 0, recommended: 3)
        ]
        let target = ActiveWorkoutNextUp.resolve(
            logs: logs,
            currentIndex: 0,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "" }
        )
        #expect(target == .nextExercise(name: "Row"))
        #expect(
            ActiveWorkoutNextUp.loggedSetProgressNote(target: target, done: 3, recommended: 3)
                == "Next up: Row"
        )
    }

    @Test func readyToFinish_whenEveryCountableExerciseIsDone() {
        let logs = [
            workingLog(name: "Bench Press", sets: 3, recommended: 3),
            placeholderLog(),
            workingLog(name: "Row", sets: 3, recommended: 3)
        ]
        #expect(ActiveWorkoutNextUp.isReadyToFinish(in: logs))
        let target = ActiveWorkoutNextUp.resolve(
            logs: logs,
            currentIndex: 2,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "" }
        )
        #expect(target == .readyToFinish)
        #expect(
            ActiveWorkoutNextUp.loggedSetProgressNote(target: target, done: 3, recommended: 3)
                == "All planned sets logged"
        )
    }

    @Test func skipsPlaceholdersAndLooksAhead() {
        let logs = [
            workingLog(name: "Squat", sets: 4, recommended: 4),
            placeholderLog(),
            workingLog(name: "RDL", sets: 1, recommended: 3)
        ]
        let target = ActiveWorkoutNextUp.resolve(
            logs: logs,
            currentIndex: 0,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "" }
        )
        #expect(target == .nextExercise(name: "RDL"))
    }

    @Test func emptyCountableLogs_areUnknown() {
        #expect(ActiveWorkoutNextUp.isReadyToFinish(in: []) == false)
        #expect(
            ActiveWorkoutNextUp.resolve(
                logs: [placeholderLog()],
                currentIndex: 0,
                displayName: { $0.snapshot?.nameAtTimeOfLog ?? "" }
            ) == .unknown
        )
    }

    private func workingLog(name: String, sets: Int, recommended: Int) -> ExerciseLog {
        ActiveWorkoutNextUpTestFixtures.workingLog(name: name, sets: sets, recommended: recommended)
    }

    private func placeholderLog() -> ExerciseLog {
        ActiveWorkoutNextUpTestFixtures.placeholderLog()
    }
}

@Suite struct ActiveWorkoutFocusAdvanceTests {
    @Test func staysPut_whileWorkSetsRemain() {
        let bench = UUID()
        let row = UUID()
        let logs = [
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Bench Press", id: bench, sets: 2, recommended: 3),
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Row", id: row, sets: 0, recommended: 3)
        ]
        #expect(ActiveWorkoutFocusAdvance.nextPrimaryExerciseId(logs: logs, currentIndex: 0) == nil)
    }

    @Test func advancesToNextIncomplete_afterPrescribedSets() {
        let bench = UUID()
        let row = UUID()
        let logs = [
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Bench Press", id: bench, sets: 3, recommended: 3),
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Row", id: row, sets: 0, recommended: 3)
        ]
        #expect(ActiveWorkoutFocusAdvance.nextPrimaryExerciseId(logs: logs, currentIndex: 0) == row)
    }

    @Test func skipsPlaceholders() {
        let squat = UUID()
        let rdl = UUID()
        let logs = [
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Squat", id: squat, sets: 4, recommended: 4),
            ActiveWorkoutNextUpTestFixtures.placeholderLog(),
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "RDL", id: rdl, sets: 0, recommended: 3)
        ]
        #expect(ActiveWorkoutFocusAdvance.nextPrimaryExerciseId(logs: logs, currentIndex: 0) == rdl)
    }

    @Test func staysPut_whenReadyToFinish() {
        let bench = UUID()
        let logs = [
            ActiveWorkoutNextUpTestFixtures.workingLog(name: "Bench Press", id: bench, sets: 3, recommended: 3)
        ]
        #expect(ActiveWorkoutFocusAdvance.nextPrimaryExerciseId(logs: logs, currentIndex: 0) == nil)
    }
}

@Suite struct WorkoutRestTimerBarCopyTests {
    @Test func subtitle_namesSameAndNextExercise() {
        #expect(
            WorkoutRestTimerBarCopy.subtitle(for: .sameExercise(name: "Bench Press"))
                == "Next set: Bench Press"
        )
        #expect(
            WorkoutRestTimerBarCopy.subtitle(for: .nextExercise(name: "Row"))
                == "Up next: Row"
        )
        #expect(WorkoutRestTimerBarCopy.subtitle(for: .readyToFinish) == "Then finish")
    }

    @Test func subtitle_unknownKeepsSwipeHint() {
        #expect(
            WorkoutRestTimerBarCopy.subtitle(for: .unknown)
                == "Swipe left or right to add or subtract 15 seconds"
        )
        #expect(WorkoutRestTimerBarCopy.namedSubtitle(for: .unknown) == nil)
    }

    @Test func restCountdownLabel_clampsNegative() {
        #expect(WorkoutRestTimerBarCopy.restCountdownLabel(seconds: 45) == "Rest 45s")
        #expect(WorkoutRestTimerBarCopy.restCountdownLabel(seconds: -1) == "Rest 0s")
    }
}

enum ActiveWorkoutNextUpTestFixtures {
    static func workingLog(name: String, id: UUID = UUID(), sets: Int, recommended: Int) -> ExerciseLog {
        let exercise = Exercise(id: id, name: name, description: "", targetedMuscles: [.chest])
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

    static func placeholderLog() -> ExerciseLog {
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
