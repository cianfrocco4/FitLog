//
//  PriorWorkoutSubstitutionLookupTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct PriorWorkoutSubstitutionLookupTests {

    @Test func stableRowShowsLastSwap() {
        let libraryId = UUID()
        let rowId = UUID()
        let bench = exercise("Bench Press")
        let dumbbell = exercise("Dumbbell Bench Press")
        let libraryRow = concrete(bench, id: rowId)
        let library = workout(id: libraryId, exercises: [libraryRow])
        let completed = completedSession(
            libraryId: libraryId,
            exercises: [concrete(dumbbell, id: rowId)],
            end: Date(timeIntervalSince1970: 2_000)
        )
        let live = liveSession(libraryId: libraryId, exercises: [libraryRow])

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(found?.exerciseId == dumbbell.id)
        #expect(found?.exerciseName == "Dumbbell Bench Press")
    }

    @Test func plannedExerciseOnLatestCompletionIsNotASwap() {
        let libraryId = UUID()
        let rowId = UUID()
        let bench = exercise("Bench Press")
        let dumbbell = exercise("Dumbbell Bench Press")
        let libraryRow = concrete(bench, id: rowId)
        let library = workout(id: libraryId, exercises: [libraryRow])
        let olderSwap = completedSession(
            libraryId: libraryId,
            exercises: [concrete(dumbbell, id: rowId)],
            end: Date(timeIntervalSince1970: 1_000)
        )
        let latestAsPlanned = completedSession(
            libraryId: libraryId,
            exercises: [concrete(bench, id: rowId)],
            end: Date(timeIntervalSince1970: 3_000)
        )
        let live = liveSession(libraryId: libraryId, exercises: [libraryRow])

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [olderSwap, latestAsPlanned]
        )

        #expect(found == nil)
    }

    @Test func hidesSwapWhenCurrentRowAlreadyUsesIt() {
        let libraryId = UUID()
        let rowId = UUID()
        let bench = exercise("Bench Press")
        let dumbbell = exercise("Dumbbell Bench Press")
        let library = workout(id: libraryId, exercises: [concrete(bench, id: rowId)])
        let completed = completedSession(
            libraryId: libraryId,
            exercises: [concrete(dumbbell, id: rowId)],
            end: Date(timeIntervalSince1970: 2_000)
        )
        let live = liveSession(libraryId: libraryId, exercises: [concrete(dumbbell, id: rowId)])

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(found == nil)
    }

    @Test func flexibleSessionMatchesBySlotWhenRowIdsChange() {
        let libraryId = UUID()
        let slotId = UUID()
        let planned = exercise("Lat Pulldown")
        let swapped = exercise("Pull-Up")
        let libraryRow = flexibleRow(defaultExercise: planned, slotId: slotId)
        let library = workout(id: libraryId, exercises: [libraryRow])

        let historicalRowId = UUID()
        let historicalRow = concrete(swapped, id: historicalRowId)
        let completed = completedSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [historicalRow],
            slotMap: [historicalRowId: slotId],
            end: Date(timeIntervalSince1970: 2_000)
        )

        let liveRowId = UUID()
        let liveRow = concrete(planned, id: liveRowId)
        let live = liveSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [liveRow],
            slotMap: [liveRowId: slotId]
        )

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(found?.exerciseId == swapped.id)
        #expect(found?.exerciseName == "Pull-Up")
    }

    @Test func indexFallbackSkipsWhenExerciseCountChanged() {
        let libraryId = UUID()
        let planned = exercise("Squat")
        let swapped = exercise("Hack Squat")
        let extra = exercise("Walk")
        let library = workout(id: libraryId, exercises: [concrete(planned)])
        let completed = completedSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [concrete(swapped), concrete(extra)],
            end: Date(timeIntervalSince1970: 2_000)
        )
        let live = liveSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [concrete(planned)]
        )

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(found == nil)
    }

    @Test func indexFallbackFindsSwapWhenRowIdsWereRegenerated() {
        let libraryId = UUID()
        let squat = exercise("Squat")
        let hack = exercise("Hack Squat")
        let row = exercise("Seated Row")
        let library = workout(id: libraryId, exercises: [concrete(squat), concrete(row)])
        let completed = completedSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [concrete(hack), concrete(row)],
            end: Date(timeIntervalSince1970: 2_000)
        )
        let live = liveSession(
            libraryId: libraryId,
            workoutId: UUID(),
            exercises: [concrete(squat), concrete(row)]
        )

        let squatSwap = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )
        let rowSwap = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[1],
            exerciseIndex: 1,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(squatSwap?.exerciseId == hack.id)
        #expect(rowSwap == nil)
    }

    @Test func swapWithNoLoggedSetsIsIgnored() {
        let libraryId = UUID()
        let rowId = UUID()
        let bench = exercise("Bench Press")
        let dumbbell = exercise("Dumbbell Bench Press")
        let swappedRow = concrete(dumbbell, id: rowId)
        let library = workout(id: libraryId, exercises: [concrete(bench, id: rowId)])
        var completed = completedSession(
            libraryId: libraryId,
            exercises: [swappedRow],
            end: Date(timeIntervalSince1970: 2_000)
        )
        completed.exerciseLogs[0].loggedSets = []
        let live = liveSession(libraryId: libraryId, exercises: [concrete(bench, id: rowId)])

        let found = PriorWorkoutSubstitutionLookup.lastSubstitution(
            for: live.exerciseLogs[0],
            exerciseIndex: 0,
            session: live,
            libraryWorkout: library,
            completedSessions: [completed]
        )

        #expect(found == nil)
    }

    private func exercise(_ name: String) -> Exercise {
        Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest])
    }

    private func concrete(_ exercise: Exercise, id: UUID = UUID()) -> WorkoutExercise {
        WorkoutExercise(id: id, exercise: exercise)
    }

    private func flexibleRow(defaultExercise: Exercise, slotId: UUID) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: slotId,
                    label: "Pull",
                    targetedMuscles: [.lats],
                    defaultExerciseId: defaultExercise.id
                )
            )
        )
    }

    private func workout(id: UUID, exercises: [WorkoutExercise]) -> Workout {
        Workout(id: id, name: "Push", exercises: exercises)
    }

    private func loggedSet() -> LoggedSet {
        LoggedSet(id: UUID(), weight: 100, reps: 8, restTime: 90, timestamp: Date(), setType: .working)
    }

    private func liveSession(
        libraryId: UUID,
        workoutId: UUID? = nil,
        exercises: [WorkoutExercise],
        slotMap: [UUID: UUID] = [:]
    ) -> WorkoutSession {
        let workout = Workout(
            id: workoutId ?? libraryId,
            name: "Push",
            exercises: exercises,
            templateSlotIdByWorkoutExerciseId: slotMap
        )
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date(),
            exerciseLogs: exercises.map { ExerciseLog(id: UUID(), workoutExercise: $0, loggedSets: []) },
            sessionPlanOrigin: .workout(libraryId)
        )
    }

    private func completedSession(
        libraryId: UUID,
        workoutId: UUID? = nil,
        exercises: [WorkoutExercise],
        slotMap: [UUID: UUID] = [:],
        end: Date
    ) -> WorkoutSession {
        let workout = Workout(
            id: workoutId ?? libraryId,
            name: "Push",
            exercises: exercises,
            templateSlotIdByWorkoutExerciseId: slotMap
        )
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: exercises.map { ExerciseLog(id: UUID(), workoutExercise: $0, loggedSets: [loggedSet()]) },
            sessionPlanOrigin: .workout(libraryId)
        )
    }
}
