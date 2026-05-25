//
//  SwiftDataMigrationV3ToV4Tests.swift
//  FitLogTests
//
//  Ensures on-disk V3 stores upgrade via custom migration to V4 without data loss.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

private func withIsolatedMigrationBackups<T>(_ body: () throws -> T) throws -> T {
    let isolatedBackupDir = FileManager.default.temporaryDirectory.appending(
        path: "FitLogMigrationBackups_\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: isolatedBackupDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: isolatedBackupDir) }
    return try FitLogMigrationPlan.$backupDirectoryOverride.withValue(isolatedBackupDir, operation: body)
}

struct SwiftDataMigrationV3ToV4Tests {

    @Test func diskStore_migratesV3ToV4AndPreservesRows() throws {
        try withIsolatedMigrationBackups {
        let basename = "FitLogV3V4MigrationTest_\(UUID().uuidString)"
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
            let v3Schema = Schema(versionedSchema: FitLogSchemaV3.self)
            let v3Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v3Container = try ModelContainer(for: v3Schema, configurations: [v3Config])
            let v3ctx = ModelContext(v3Container)
            let exercise = SDExerciseV3(
                exerciseId: UUID(),
                name: "Bench Press",
                exerciseDescription: "Flat",
                targetedMusclesData: versionedEncode(["Chest"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.horizontalPush.rawValue
            )
            v3ctx.insert(exercise)
            try v3ctx.save()
        }

        let v4Schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let v4Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v4Container = try ModelContainer(
            for: v4Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v4Config]
        )
        let v4ctx = ModelContext(v4Container)
        let exercises = try v4ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Bench Press" })
        #expect(exercises.first?.modalityRaw == ExerciseModality.strength.rawValue)
        #expect(exercises.first?.cardioMetadataData.isEmpty == true)
        let anchors = try v4ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.schemaVersionMajor == 4)
        }
    }

    @Test func diskStore_migratesV3ToV4_fullGraph() throws {
        try withIsolatedMigrationBackups {
        let basename = "FitLogV3V4FullGraphTest_\(UUID().uuidString)"
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
        let rowId = UUID()
        let slotId = UUID()
        let sessionId = UUID()
        let logId = UUID()
        let setId = UUID()
        let presetId = UUID()
        let programId = UUID()

        do {
            let v3Schema = Schema(versionedSchema: FitLogSchemaV3.self)
            let v3Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v3Container = try ModelContainer(for: v3Schema, configurations: [v3Config])
            let v3ctx = ModelContext(v3Container)

            let exercise = SDExerciseV3(
                exerciseId: exerciseId,
                name: "Bench Press",
                exerciseDescription: "Flat",
                targetedMusclesData: versionedEncode(["Chest"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.horizontalPush.rawValue
            )
            v3ctx.insert(exercise)

            let workout = SDWorkoutV3(workoutId: workoutId, name: "Push Day", sortOrder: 0)
            v3ctx.insert(workout)

            let slot = SDSlotBlueprintV3(
                blueprintId: slotId,
                label: "Chest Press",
                targetedMusclesData: versionedEncode(["Chest"]),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.horizontalPush.rawValue,
                defaultExerciseId: exerciseId,
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8-12"
            )
            v3ctx.insert(slot)

            let row = SDWorkoutExerciseRowV3()
            row.rowId = rowId
            row.orderIndex = 0
            row.resolutionTypeRaw = "flexible"
            row.workout = workout
            row.defaultExercise = exercise
            row.slot = slot
            slot.exerciseRow = row
            v3ctx.insert(row)

            let slotBlueprint = SlotBlueprint(
                id: slotId,
                label: "Chest Press",
                targetedMuscles: [.chest],
                exerciseRole: .compound,
                movementPattern: .horizontalPush,
                defaultExerciseId: exerciseId
            )
            let workoutExercise = WorkoutExercise(
                id: rowId,
                resolution: .flexible(slotBlueprint)
            )
            let workoutDomain = Workout(id: workoutId, name: "Push Day", exercises: [workoutExercise])

            let loggedSet = SDLoggedSetV3()
            loggedSet.setId = setId
            loggedSet.orderIndex = 0
            loggedSet.weight = 135
            loggedSet.reps = 8
            v3ctx.insert(loggedSet)

            let exerciseLog = SDExerciseLogV3()
            exerciseLog.logId = logId
            exerciseLog.orderIndex = 0
            exerciseLog.nameSnapshot = "Bench Press"
            exerciseLog.exerciseIdSnapshot = exerciseId
            exerciseLog.workoutExerciseData = versionedEncode(workoutExercise)
            exerciseLog.exercise = exercise
            exerciseLog.sets = [loggedSet]
            loggedSet.log = exerciseLog
            v3ctx.insert(exerciseLog)

            let session = SDWorkoutSessionV3()
            session.sessionId = sessionId
            session.startTime = Date(timeIntervalSince1970: 1_700_000_000)
            session.workoutSnapshotData = versionedEncode(workoutDomain)
            session.activeExerciseIdsData = versionedEncode([rowId])
            session.completedExerciseIdsData = versionedEncode([rowId])
            session.workout = workout
            session.logs = [exerciseLog]
            exerciseLog.session = session
            v3ctx.insert(session)

            let program = SDTrainingProgramV3()
            program.sessionsPerWeek = 4
            program.anchorDayKey = "2026-05-01"
            v3ctx.insert(program)

            let cycleEntry = SDProgramCycleEntryV3(orderIndex: 0, workoutId: workoutId)
            cycleEntry.program = program
            cycleEntry.referencedWorkout = workout
            v3ctx.insert(cycleEntry)

            let frozenDay = SDFrozenPlanDayV3()
            frozenDay.dayKey = "2026-05-01"
            frozenDay.kindRaw = FrozenPlanDay.Kind.workout.rawValue
            frozenDay.workoutRefData = versionedEncode(WorkoutPlanRef.workout(workoutId))
            frozenDay.program = program
            v3ctx.insert(frozenDay)

            let preset = SDSplitPresetV2(
                presetId: presetId,
                name: "PPL Split",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                notes: "Test preset",
                sessionsPerWeek: 3
            )
            v3ctx.insert(preset)

            let dynamicProgram = DynamicProgram(
                id: programId,
                name: "Strength Block",
                blocks: [],
                defaultSessionsPerWeek: 3
            )
            v3ctx.insert(SDDynamicProgramV2.from(DynamicProgramState(program: dynamicProgram, anchorDate: Date(timeIntervalSince1970: 1_700_000_000))))

            try v3ctx.save()
        }

        let v4Schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let v4Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v4Container = try ModelContainer(
            for: v4Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v4Config]
        )
        let v4ctx = ModelContext(v4Container)

        let exercises = try v4ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Bench Press" })

        let workouts = try v4ctx.fetch(FetchDescriptor<SDWorkoutV2>())
        #expect(workouts.contains { $0.name == "Push Day" })
        let migratedWorkout = try #require(workouts.first { $0.name == "Push Day" })
        #expect(migratedWorkout.rows.count == 1)
        #expect(migratedWorkout.rows.first?.recommendedReps == "8-12")

        let sessions = try v4ctx.fetch(FetchDescriptor<SDWorkoutSessionV2>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.logs.count == 1)
        #expect(sessions.first?.logs.first?.sets.first?.reps == 8)

        let programs = try v4ctx.fetch(FetchDescriptor<SDTrainingProgramV2>())
        #expect(programs.first?.anchorDayKey == "2026-05-01")
        #expect(programs.first?.cycleEntries.count == 1)

        let presets = try v4ctx.fetch(FetchDescriptor<SDSplitPresetV2>())
        #expect(presets.contains { $0.name == "PPL Split" })

        let dynamicRows = try v4ctx.fetch(FetchDescriptor<SDDynamicProgramV2>())
        #expect(dynamicRows.count == 1)
        #expect(dynamicRows.first?.toDomain()?.program.name == "Strength Block")

        let anchors = try v4ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.schemaVersionMajor == 4)
        }
    }

    @Test func modelContainer_openV4Schema_doesNotDuplicateChecksums() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [config]
        )
        #expect(container.schema.version == Schema.Version(4, 0, 0))
    }
}
