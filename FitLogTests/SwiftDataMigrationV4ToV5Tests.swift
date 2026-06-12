//
//  SwiftDataMigrationV4ToV5Tests.swift
//  FitLogTests
//
//  Ensures on-disk V4 stores upgrade via lightweight migration to V5 and preserve data.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct SwiftDataMigrationV4ToV5Tests {

    @Test func diskStore_migratesV4ToV5AndPreservesRows() throws {
        let basename = "FitLogV4V5MigrationTest_\(UUID().uuidString)"
        let storeURL = FileManager.default.temporaryDirectory.appending(
            path: "\(basename).store",
            directoryHint: .notDirectory
        )

        func removeArtifacts() {
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: url)
            }
        }

        removeArtifacts()
        defer { removeArtifacts() }

        do {
            let v4Schema = Schema(versionedSchema: FitLogSchemaV4.self)
            let v4Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v4Container = try ModelContainer(for: v4Schema, configurations: [v4Config])
            let v4ctx = ModelContext(v4Container)
            let exercise = SDExerciseV2(
                exerciseId: UUID(),
                name: "Squat",
                exerciseDescription: "Barbell",
                targetedMusclesData: versionedEncode(["Quads"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.squat.rawValue
            )
            v4ctx.insert(exercise)
            v4ctx.insert(SDSchemaMigrationAnchorV4())
            try v4ctx.save()
        }

        let v5Schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let v5Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v5Container = try ModelContainer(
            for: v5Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v5Config]
        )
        let v5ctx = ModelContext(v5Container)

        let exercises = try v5ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Squat" })

        let anchors = try v5ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
        #expect(anchors.count == 1)

        let conversations = try v5ctx.fetch(FetchDescriptor<SDCoachConversationV5>())
        #expect(conversations.isEmpty)
    }

    @Test func diskStore_migratesV4ToV5_preservesRichGraph() throws {
        let basename = "FitLogV4V5RichGraphTest_\(UUID().uuidString)"
        let storeURL = FileManager.default.temporaryDirectory.appending(
            path: "\(basename).store",
            directoryHint: .notDirectory
        )

        func removeArtifacts() {
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: url)
            }
        }

        removeArtifacts()
        defer { removeArtifacts() }

        let exerciseId = UUID()
        let workoutId = UUID()
        let sessionId = UUID()
        let setId = UUID()
        let prId = UUID()
        let sessionStart = Date(timeIntervalSince1970: 1_700_000_000)

        do {
            let v4Schema = Schema(versionedSchema: FitLogSchemaV4.self)
            let v4Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v4Container = try ModelContainer(for: v4Schema, configurations: [v4Config])
            let v4ctx = ModelContext(v4Container)

            let exercise = SDExerciseV2(
                exerciseId: exerciseId,
                name: "Squat",
                exerciseDescription: "Barbell back squat",
                targetedMusclesData: versionedEncode(["Quads"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.squat.rawValue
            )
            v4ctx.insert(exercise)

            let workout = SDWorkoutV2(workoutId: workoutId, name: "Leg Day", sortOrder: 0)
            v4ctx.insert(workout)

            let row = SDWorkoutExerciseRowV2.from(
                WorkoutExercise(id: UUID(), exercise: exercise.toDomain(), recommendedSets: 3, recommendedReps: "5"),
                orderIndex: 0
            )
            row.workout = workout
            v4ctx.insert(row)
            workout.rows = [row]

            let loggedSet = SDLoggedSetV2.from(
                LoggedSet(
                    id: setId,
                    weight: 225,
                    reps: 5,
                    restTime: 180,
                    timestamp: sessionStart,
                    setType: .dropSet,
                    configuration: [:],
                    dropSegments: [DropSetSegment(weight: 185, reps: 8)],
                    rpe: 8.5
                ),
                orderIndex: 0
            )
            v4ctx.insert(loggedSet)

            let exerciseLog = SDExerciseLogV2.from(
                ExerciseLog(id: UUID(), workoutExercise: row.toDomain(), loggedSets: [loggedSet.toDomain()]),
                orderIndex: 0
            )
            exerciseLog.exercise = exercise
            v4ctx.insert(exerciseLog)

            let session = SDWorkoutSessionV2.from(
                WorkoutSession(
                    id: sessionId,
                    workout: workout.toDomain(),
                    startTime: sessionStart,
                    endTime: Date(timeIntervalSince1970: 1_700_001_800),
                    exerciseLogs: [exerciseLog.toDomain()!]
                )
            )
            session.workout = workout
            v4ctx.insert(session)

            var programState = TrainingProgramState.empty(anchorDayKey: "2026-05-01")
            programState.cycleEntries = [.workout(workoutId)]
            let program = SDTrainingProgramV2.from(programState)
            v4ctx.insert(program)

            v4ctx.insert(
                SDPersonalRecordV2(
                    prId: prId,
                    exerciseId: exerciseId,
                    kindRaw: PRKind.maxWeight.rawValue,
                    value: 225,
                    setId: setId,
                    sessionId: sessionId,
                    achievedAt: sessionStart
                )
            )

            v4ctx.insert(SDSchemaMigrationAnchorV4())
            try v4ctx.save()
        }

        let v5Schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let v5Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v5Container = try ModelContainer(
            for: v5Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v5Config]
        )
        let v5ctx = ModelContext(v5Container)

        let exercises = try v5ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Squat" })

        let sessions = try v5ctx.fetch(FetchDescriptor<SDWorkoutSessionV2>())
        #expect(sessions.count == 1)
        let migratedSession = try #require(sessions.first)
        #expect(migratedSession.sessionId == sessionId)
        #expect(migratedSession.logs.count == 1)

        let migratedLog = try #require(migratedSession.logs.first)
        #expect(migratedLog.sets.count == 1)

        let migratedSet = try #require(migratedLog.sets.first)
        #expect(migratedSet.setId == setId)
        #expect(migratedSet.weight == 225)
        #expect(migratedSet.reps == 5)
        #expect(migratedSet.rpe == 8.5)
        #expect(migratedSet.dropSegments.count == 1)

        let migratedDrop = try #require(migratedSet.dropSegments.first)
        #expect(migratedDrop.weight == 185)
        #expect(migratedDrop.reps == 8)

        let snapshotWorkout = versionedDecode(Workout.self, from: migratedSession.workoutSnapshotData)
        #expect(snapshotWorkout?.name == "Leg Day")

        let programs = try v5ctx.fetch(FetchDescriptor<SDTrainingProgramV2>())
        #expect(programs.count == 1)
        let migratedProgram = try #require(programs.first)
        #expect(migratedProgram.cycleEntries.count == 1)
        #expect(migratedProgram.cycleEntries.first?.workoutId == workoutId)

        let prs = try v5ctx.fetch(FetchDescriptor<SDPersonalRecordV2>())
        #expect(prs.count == 1)
        #expect(prs.first?.prId == prId)
        #expect(prs.first?.value == 225)
        #expect(prs.first?.kindRaw == PRKind.maxWeight.rawValue)

        let anchors = try v5ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
        #expect(anchors.count == 1)

        let conversations = try v5ctx.fetch(FetchDescriptor<SDCoachConversationV5>())
        #expect(conversations.isEmpty)
    }

    @Test @MainActor func coachChatStore_roundTrip() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        let store = CoachChatStore(modelContext: ctx, failureReporter: PersistenceFailureReporter())

        let conversationID = store.createConversation()
        let user = CoachChatMessage(role: .user, text: "How is my split?")
        #expect(store.appendMessage(user, conversationID: conversationID))

        let assistant = CoachChatMessage(role: .assistant, text: "Your split looks balanced.")
        #expect(store.appendMessage(assistant, conversationID: conversationID))

        let loaded = store.loadMessages(conversationID: conversationID)
        #expect(loaded.count == 2)
        #expect(loaded.first?.text == "How is my split?")
        #expect(loaded.last?.text == "Your split looks balanced.")

        #expect(store.setFeedback(messageID: assistant.id, conversationID: conversationID, feedback: .up))
        let reloaded = store.loadMessages(conversationID: conversationID)
        #expect(reloaded.last?.feedback == .up)

        let summaries = store.loadConversations()
        #expect(summaries.count == 1)
        #expect(summaries.first?.messageCount == 2)
    }
}
