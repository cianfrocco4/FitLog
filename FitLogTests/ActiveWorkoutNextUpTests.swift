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
        let exercise = Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest])
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

@Suite struct RestTimerNextUpCopyTests {
    @Test func headlineAndBody_nameTheNextExercise() {
        #expect(
            RestTimerNextUpCopy.headline(for: .sameExercise(name: "Bench Press"))
                == "Rest — next: Bench Press"
        )
        #expect(
            RestTimerNextUpCopy.notificationBody(for: .sameExercise(name: "Bench Press"))
                == "Time for your next Bench Press set"
        )
        #expect(
            RestTimerNextUpCopy.headline(for: .nextExercise(name: "Row"))
                == "Rest — next: Row"
        )
        #expect(RestTimerNextUpCopy.notificationBody(for: .nextExercise(name: "Row")) == "Next up: Row")
    }

    @Test func headlineAndBody_readyToFinish() {
        #expect(RestTimerNextUpCopy.headline(for: .readyToFinish) == "Rest — then finish")
        #expect(
            RestTimerNextUpCopy.notificationBody(for: .readyToFinish)
                == "Last rest — finish when you're ready"
        )
    }

    @Test func headlineAndBody_unknownKeepGenericCopy() {
        #expect(RestTimerNextUpCopy.headline(for: .unknown) == "Rest between sets")
        #expect(RestTimerNextUpCopy.notificationBody(for: .unknown) == "Time for the next set")
    }
}
