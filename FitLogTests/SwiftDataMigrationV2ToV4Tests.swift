//
//  SwiftDataMigrationV2ToV4Tests.swift
//  FitLogTests
//
//  Ensures on-disk V2.0.1 stores upgrade through V3 to V4 without data loss.
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

struct SwiftDataMigrationV2ToV4Tests {

    @Test func diskStore_migratesV2ToV4AndPreservesRows() throws {
        try withIsolatedMigrationBackups {
            let basename = "FitLogV2V4MigrationTest_\(UUID().uuidString)"
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
            let presetId = UUID()
            let prId = UUID()
            let setId = UUID()

            do {
                let v2Schema = Schema(versionedSchema: FitLogSchemaV2.self)
                let v2Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
                let v2Container = try ModelContainer(for: v2Schema, configurations: [v2Config])
                let v2ctx = ModelContext(v2Container)

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
                v2ctx.insert(exercise)

                let workout = SDWorkoutV2(workoutId: workoutId, name: "Leg Day", sortOrder: 0)
                v2ctx.insert(workout)

                let row = SDWorkoutExerciseRowV2.from(
                    WorkoutExercise(id: UUID(), exercise: exercise.toDomain(), recommendedSets: 3, recommendedReps: "5"),
                    orderIndex: 0
                )
                row.workout = workout
                v2ctx.insert(row)
                workout.rows = [row]

                let loggedSet = SDLoggedSetV2.from(
                    LoggedSet(id: setId, weight: 225, reps: 5, restTime: 180, timestamp: Date(timeIntervalSince1970: 1_700_000_000), setType: .working, configuration: [:], dropSegments: [], rpe: nil),
                    orderIndex: 0
                )
                v2ctx.insert(loggedSet)

                let exerciseLog = SDExerciseLogV2.from(
                    ExerciseLog(id: UUID(), workoutExercise: row.toDomain(), loggedSets: [loggedSet.toDomain()]),
                    orderIndex: 0
                )
                exerciseLog.exercise = exercise
                v2ctx.insert(exerciseLog)

                let session = SDWorkoutSessionV2.from(
                    WorkoutSession(
                        id: sessionId,
                        workout: workout.toDomain(),
                        startTime: Date(timeIntervalSince1970: 1_700_000_000),
                        endTime: Date(timeIntervalSince1970: 1_700_001_800),
                        exerciseLogs: [exerciseLog.toDomain()!]
                    )
                )
                session.workout = workout
                v2ctx.insert(session)

                let program = SDTrainingProgramV2.from(
                    TrainingProgramState.empty(anchorDayKey: "2026-05-01")
                )
                v2ctx.insert(program)

                let preset = SDSplitPresetV2(
                    presetId: presetId,
                    name: "Leg Focus",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    notes: "",
                    sessionsPerWeek: 2
                )
                v2ctx.insert(preset)

                v2ctx.insert(
                    SDPersonalRecordV2(
                        prId: prId,
                        exerciseId: exerciseId,
                        kindRaw: PRKind.maxWeight.rawValue,
                        value: 225,
                        setId: setId,
                        sessionId: sessionId,
                        achievedAt: Date(timeIntervalSince1970: 1_700_000_000)
                    )
                )

                try v2ctx.save()
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
            #expect(exercises.contains { $0.name == "Squat" })

            let workouts = try v4ctx.fetch(FetchDescriptor<SDWorkoutV2>())
            #expect(workouts.contains { $0.name == "Leg Day" })

            let sessions = try v4ctx.fetch(FetchDescriptor<SDWorkoutSessionV2>())
            #expect(sessions.count == 1)
            #expect(sessions.first?.logs.first?.sets.first?.weight == 225)

            let presets = try v4ctx.fetch(FetchDescriptor<SDSplitPresetV2>())
            #expect(presets.contains { $0.name == "Leg Focus" })

            let prs = try v4ctx.fetch(FetchDescriptor<SDPersonalRecordV2>())
            #expect(prs.contains { $0.prId == prId && $0.value == 225 })

            let anchors = try v4ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
            #expect(anchors.count == 1)
        }
    }
}
