//
//  ActiveWorkoutPersistenceTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct ActiveWorkoutPersistenceTests {

    @Test func markExerciseCompleted_persistsThroughActiveSessionStore() throws {
        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let exerciseId = UUID()
        let we = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(
                ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Squat")
            ),
            recommendedSets: 3,
            recommendedReps: "5"
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Legs", exercises: [we]),
            startTime: Date(),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [])],
            activeExerciseIds: [exerciseId]
        )
        vm.currentSession = session

        vm.markExerciseCompleted(exerciseId: exerciseId)

        let restored = dm.sessionStore.loadActiveSession()
        #expect(restored != nil)
        #expect(restored?.completedExerciseIds.contains(exerciseId) == true)
        #expect(restored?.activeExerciseIds.contains(exerciseId) == false)
    }

    @Test func toggleSupersetAndSetPrimary_persistThroughActiveSessionStore() throws {
        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let primaryId = UUID()
        let secondaryId = UUID()
        let we1 = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: primaryId, nameAtTimeOfLog: "Bench")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let we2 = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: secondaryId, nameAtTimeOfLog: "Row")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        vm.currentSession = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push", exercises: [we1, we2]),
            startTime: Date(),
            exerciseLogs: [
                ExerciseLog(id: UUID(), workoutExercise: we1, loggedSets: []),
                ExerciseLog(id: UUID(), workoutExercise: we2, loggedSets: [])
            ],
            activeExerciseIds: [primaryId]
        )

        vm.toggleSupersetExercise(exerciseId: secondaryId)
        vm.setPrimaryExercise(exerciseId: secondaryId)

        let restored = dm.sessionStore.loadActiveSession()
        #expect(restored?.activeExerciseIds.first == secondaryId)
        #expect(restored?.activeExerciseIds.contains(primaryId) == true)
        #expect(restored?.activeExerciseIds.contains(secondaryId) == true)
    }

    @Test func deleteSet_withNilExerciseId_stillMutatesAndPersists() throws {
        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let openSlot = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Pick later",
                    targetedMuscles: [.chest],
                    defaultExerciseId: nil
                )
            ),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        #expect(openSlot.exerciseId == nil)

        let emptySet = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 90,
            timestamp: Date(),
            isWarmup: false,
            configuration: [:],
            dropSegments: [],
            rpe: nil
        )
        vm.currentSession = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Flexible", exercises: [openSlot]),
            startTime: Date(),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: openSlot, loggedSets: [emptySet])]
        )

        vm.deleteSet(exerciseIndex: 0, setIndex: 0)

        #expect(vm.currentSession?.exerciseLogs[0].loggedSets.isEmpty == true)
        let restored = dm.sessionStore.loadActiveSession()
        #expect(restored?.exerciseLogs[0].loggedSets.isEmpty == true)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
