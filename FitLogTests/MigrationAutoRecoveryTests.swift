//
//  MigrationAutoRecoveryTests.swift
//  FitLogTests
//
//  Verifies silent auto-recovery when disk ModelContainer open fails.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite(.serialized)
struct MigrationAutoRecoveryTests {

    @Test func openContainerWithRecovery_restoresFromBackupWhenStoreIsCorrupt() throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(
            path: "FitLogAutoRecoveryBackupTest_\(UUID().uuidString).store",
            directoryHint: .notDirectory
        )
        let isolatedBackupDir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogAutoRecoveryBackups_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: isolatedBackupDir, withIntermediateDirectories: true)
        defer {
            FitLogApp.removeStoreArtifacts(at: storeURL)
            try? FileManager.default.removeItem(at: isolatedBackupDir)
        }

        try FitLogMigrationPlan.$backupDirectoryOverride.withValue(isolatedBackupDir) {
            FitLogApp.removeStoreArtifacts(at: storeURL)
            try Data("not a sqlite store".utf8).write(to: storeURL, options: .atomic)

            let exerciseId = UUID()
            let snapshot = BackupSnapshot(
                schemaVersion: currentSchemaVersion,
                exercises: [
                    Exercise(
                        id: exerciseId,
                        name: "Auto Recovery Exercise",
                        description: "",
                        targetedMuscles: [.chest],
                        isCustom: false
                    )
                ],
                workouts: [],
                sessions: [],
                program: TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date())),
                displayNames: [:]
            )
            try FitLogMigrationPlan.writePreV4Backup(snapshot)

            let result = FitLogApp.openContainerWithRecovery(storeURL: storeURL)
            #expect(result.error == nil)

            let ctx = ModelContext(result.container)
            let exercises = try ctx.fetch(FetchDescriptor<SDExerciseV2>())
            #expect(exercises.contains { $0.name == "Auto Recovery Exercise" })
        }
    }

    @Test func openContainerWithRecovery_startsFreshWhenNoBackupExists() throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(
            path: "FitLogAutoRecoveryFreshTest_\(UUID().uuidString).store",
            directoryHint: .notDirectory
        )
        let isolatedBackupDir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogAutoRecoveryBackups_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: isolatedBackupDir, withIntermediateDirectories: true)
        defer {
            FitLogApp.removeStoreArtifacts(at: storeURL)
            try? FileManager.default.removeItem(at: isolatedBackupDir)
        }

        try FitLogMigrationPlan.$backupDirectoryOverride.withValue(isolatedBackupDir) {
            FitLogApp.removeStoreArtifacts(at: storeURL)
            try Data("not a sqlite store".utf8).write(to: storeURL, options: .atomic)

            let result = FitLogApp.openContainerWithRecovery(storeURL: storeURL)
            #expect(result.error == nil)

            let ctx = ModelContext(result.container)
            let exercises = try ctx.fetch(FetchDescriptor<SDExerciseV2>())
            #expect(exercises.isEmpty)
        }
    }
}
