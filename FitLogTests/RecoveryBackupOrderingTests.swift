//
//  RecoveryBackupOrderingTests.swift
//  FitLogTests
//
//  Recovery must prefer the newest valid snapshot; rotating prune must spare migration files.
//

import Foundation
import Testing
@testable import FitLog

@Suite(.serialized)
struct RecoveryBackupOrderingTests {

    private func makeSnapshot(exerciseName: String) -> BackupSnapshot {
        BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: [
                Exercise(
                    id: UUID(),
                    name: exerciseName,
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
    }

    private func writeSnapshot(_ snapshot: BackupSnapshot, to url: URL, modifiedAt: Date) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: url.path
        )
    }

    @Test func readBestAvailableRecoverySnapshot_prefersNewestRotatingBackupOverStalePreV4() throws {
        let dir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogRecoveryOrder_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try FitLogMigrationPlan.$backupDirectoryOverride.withValue(dir) {
            let old = makeSnapshot(exerciseName: "Old PreV4")
            let newer = makeSnapshot(exerciseName: "Newer Rotating")

            try writeSnapshot(
                old,
                to: dir.appending(path: FitLogMigrationPlan.preV4BackupFileName),
                modifiedAt: Date(timeIntervalSince1970: 1_000)
            )
            try writeSnapshot(
                newer,
                to: dir.appending(path: "backup_2026-07-26_120000.json"),
                modifiedAt: Date(timeIntervalSince1970: 2_000)
            )

            let recovered = FitLogMigrationPlan.readBestAvailableRecoverySnapshot()
            #expect(recovered?.exercises.first?.name == "Newer Rotating")
        }
    }

    @Test func pruneRotatingBackups_preservesMigrationSafetyFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogPruneProtect_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshot = makeSnapshot(exerciseName: "Keep Me")
        let data = try JSONEncoder().encode(snapshot)

        let protectedNames = [
            FitLogMigrationPlan.preV4BackupFileName,
            FitLogMigrationPlan.preV3BackupFileName,
            "pre_v2_latest.json",
            "pre_v2_2026-01-01_000000.json",
            WorkoutUnifiedSlotsMigration.latestPreMigrationBackupFileName,
            CardioSchemaMigration.latestPreMigrationBackupFileName,
        ]
        for name in protectedNames {
            try data.write(to: dir.appending(path: name), options: .atomic)
        }

        for i in 0..<10 {
            let name = String(format: "backup_2026-07-26_%02d0000.json", i)
            let url = dir.appending(path: name)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.creationDate: Date(timeIntervalSince1970: TimeInterval(1_000 + i))],
                ofItemAtPath: url.path
            )
        }

        DataManager.pruneRotatingBackups(in: dir, keepingNewest: 7)

        for name in protectedNames {
            #expect(FileManager.default.fileExists(atPath: dir.appending(path: name).path))
        }

        let remainingBackups = (try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("backup_") }
        #expect(remainingBackups.count == 7)
    }

    @Test func pruneRotatingBackups_keepingNone_deletesUserSnapshotsAndKeepsMigrationFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogPruneAllRotating_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshot = makeSnapshot(exerciseName: "Deleted User")
        let data = try JSONEncoder().encode(snapshot)
        let protected = FitLogMigrationPlan.preV4BackupFileName
        try data.write(to: dir.appending(path: protected), options: .atomic)
        try data.write(to: dir.appending(path: "backup_2026-08-17_120000.json"), options: .atomic)

        DataManager.pruneRotatingBackups(in: dir, keepingNewest: 0)

        #expect(FileManager.default.fileExists(atPath: dir.appending(path: protected).path))
        let remainingBackups = (try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("backup_") }
        #expect(remainingBackups.isEmpty)
    }

    @Test func isProtectedMigrationBackupFileName_coversExpectedPrefixes() {
        #expect(FitLogMigrationPlan.isProtectedMigrationBackupFileName("pre_v4_latest.json"))
        #expect(FitLogMigrationPlan.isProtectedMigrationBackupFileName("pre_v3_latest.json"))
        #expect(FitLogMigrationPlan.isProtectedMigrationBackupFileName("pre_v2_latest.json"))
        #expect(FitLogMigrationPlan.isProtectedMigrationBackupFileName("pre_v2_2026-07-01_120000.json"))
        #expect(FitLogMigrationPlan.isProtectedMigrationBackupFileName(
            WorkoutUnifiedSlotsMigration.latestPreMigrationBackupFileName
        ))
        #expect(!FitLogMigrationPlan.isProtectedMigrationBackupFileName("backup_2026-07-26_120000.json"))
    }
}
