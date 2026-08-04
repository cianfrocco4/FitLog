//
//  FitLogMigrationPlan.swift
//  FitLog
//
//  Custom SwiftData migration from V1 (JSON-blob @Models) to V2 (normalized graph).
//
//  **V2→V3:** Custom migration — frozen `FitLogSchemaV2` (`SD*V2` types) → frozen `FitLogSchemaV3`
//  (`SD*V3` types plus `SDDynamicProgramV2`). Lightweight migration cannot rename entity identities.
//
//  **V3→V4:** Custom migration — frozen `FitLogSchemaV3` (pre-cardio `SD*V3` types) → live `FitLogSchemaV4`
//  (`SD*V2` with cardio columns). Lightweight migration is not used because entity checksums differ.
//
//  Strategy:
//    willMigrate  — runs against the V1 context; reads all rows via their
//                   toStruct() methods, encodes a BackupSnapshot to disk, and
//                   writes it to Application Support/Backups/pre_v2_<stamp>.json
//                   as well as pre_v2_latest.json.
//    didMigrate   — runs against the new V2 context; reads the backup from disk
//                   and calls V2MigrationDecoder to populate all V2 rows and
//                   run the PR backfill.
//

import Foundation
import SwiftData
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "FitLogMigrationPlan"
)

enum FitLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FitLogSchemaV1.self, FitLogSchemaV2.self, FitLogSchemaV3.self, FitLogSchemaV4.self, FitLogSchemaV5.self, FitLogSchemaV6.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1ToV2, migrateV2ToV3, migrateV3ToV4, migrateV4ToV5, migrateV5ToV6]
    }

    // MARK: - V5 → V6

    /// Additive readiness snapshots only — lightweight migration preserves all existing user data.
    private static let migrateV5ToV6 = MigrationStage.lightweight(
        fromVersion: FitLogSchemaV5.self,
        toVersion: FitLogSchemaV6.self
    )

    // MARK: - V4 → V5

    /// Additive Coach chat models only — lightweight migration preserves all existing user data.
    private static let migrateV4ToV5 = MigrationStage.lightweight(
        fromVersion: FitLogSchemaV4.self,
        toVersion: FitLogSchemaV5.self
    )

    // MARK: - V3 → V4

    private static let migrateV3ToV4 = MigrationStage.custom(
        fromVersion: FitLogSchemaV3.self,
        toVersion: FitLogSchemaV4.self,
        willMigrate: { context in
            log.notice("V3→V4 willMigrate: reading frozen V3 rows")
            let snapshot = try V3MigrationReader.readSnapshot(from: context)
            try writePreV4Backup(snapshot)
            log.notice("V3→V4 willMigrate: backup written (exercises=\(snapshot.exercises.count), sessions=\(snapshot.sessions.count))")
        },
        didMigrate: { context in
            log.notice("V3→V4 didMigrate: populating V4 graph")
            guard let snapshot = readLatestPreV4Backup() else {
                throw FitLogMigrationError.backupNotFound
            }
            try V2MigrationDecoder.decode(snapshot: snapshot, into: context)
            let existingAnchors = (try? context.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())) ?? []
            if existingAnchors.isEmpty {
                context.insert(SDSchemaMigrationAnchorV4())
            }
            try context.save()
            log.notice("V3→V4 didMigrate: complete")
        }
    )

    // MARK: - V2 → V3

    private static let migrateV2ToV3 = MigrationStage.custom(
        fromVersion: FitLogSchemaV2.self,
        toVersion: FitLogSchemaV3.self,
        willMigrate: { context in
            log.notice("V2→V3 willMigrate: reading frozen V2 rows")
            let snapshot = try V2MigrationReader.readSnapshot(from: context)
            try writePreV3Backup(snapshot)
            log.notice(
                "V2→V3 willMigrate: backup written (exercises=\(snapshot.exercises.count), sessions=\(snapshot.sessions.count), prs=\(snapshot.personalRecords.count))"
            )
        },
        didMigrate: { context in
            log.notice("V2→V3 didMigrate: populating V3 graph")
            guard let snapshot = readLatestPreV3Backup() else {
                throw FitLogMigrationError.backupNotFound
            }
            try V3MigrationDecoder.decode(snapshot: snapshot, into: context)
            log.notice("V2→V3 didMigrate: complete")
        }
    )

    // MARK: - V1 → V2

    private static let migrateV1ToV2 = MigrationStage.custom(
        fromVersion: FitLogSchemaV1.self,
        toVersion: FitLogSchemaV2.self,
        willMigrate: { context in
            log.notice("V1→V2 willMigrate: reading V1 rows")
            let snapshot = try readV1Snapshot(from: context)
            try writeBackup(snapshot)
            log.notice("V1→V2 willMigrate: backup written (exercises=\(snapshot.exercises.count), sessions=\(snapshot.sessions.count))")
        },
        didMigrate: { context in
            log.notice("V1→V2 didMigrate: populating V2 graph")
            guard let snapshot = readLatestBackup() else {
                throw FitLogMigrationError.backupNotFound
            }
            try V2MigrationDecoder.decode(snapshot: snapshot, into: context)
            log.notice("V1→V2 didMigrate: complete")
        }
    )

    // MARK: - V1 snapshot reader

    private static func readV1Snapshot(from context: ModelContext) throws -> BackupSnapshot {
        let exercises = try context.fetch(FetchDescriptor<SDExercise>())
        let workouts = try context.fetch(FetchDescriptor<SDWorkout>(sortBy: [SortDescriptor(\.sortOrder)]))
        let sessions = try context.fetch(FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startTime)]))
        let displayNames = try context.fetch(FetchDescriptor<SDExerciseDisplayName>())
        let programs = try context.fetch(FetchDescriptor<SDTrainingProgram>())

        let exerciseStructs = exercises.map { $0.toStruct() }
        let workoutStructs = workouts.map { $0.toStruct() }
        let sessionStructs = sessions.compactMap { $0.toStruct() }
        let program = programs.first?.toStruct()
            ?? TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))
        var nameMap: [UUID: String] = [:]
        for dn in displayNames {
            let t = dn.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { nameMap[dn.exerciseId] = t }
        }

        return BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: exerciseStructs,
            workouts: workoutStructs,
            sessions: sessionStructs,
            program: program,
            displayNames: nameMap
        )
    }

    // MARK: - Backup I/O

    /// Override scoped to the current task; set only in tests so parallel runs do not race on shared backups.
    @TaskLocal static var backupDirectoryOverride: URL?

    static var backupDir: URL {
        if let override = backupDirectoryOverride {
            return override
        }
        return URL.applicationSupportDirectory
            .appending(path: "Backups", directoryHint: .isDirectory)
    }

    static func writeBackup(_ snapshot: BackupSnapshot) throws {
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = formatter.string(from: Date())
        let stampedURL = backupDir.appending(path: "pre_v2_\(stamp).json")
        let latestURL = backupDir.appending(path: "pre_v2_latest.json")

        try data.write(to: stampedURL, options: .atomic)
        try data.write(to: latestURL, options: .atomic)
    }

    static func readLatestBackup() -> BackupSnapshot? {
        let url = backupDir.appending(path: "pre_v2_latest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BackupSnapshot.self, from: data)
    }

    /// Prefers the newest valid `BackupSnapshot` JSON in Application Support/Backups by
    /// content-modification (fallback: creation) date. Never prefers a stale `pre_v*` migration
    /// snapshot over a newer rotating `backup_*.json`.
    static func readBestAvailableRecoverySnapshot() -> BackupSnapshot? {
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        func fileDate(_ url: URL) -> Date {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            return values?.contentModificationDate ?? values?.creationDate ?? .distantPast
        }

        let sortedNewestFirst = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { fileDate($0) > fileDate($1) }

        for url in sortedNewestFirst {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let snapshot = try? JSONDecoder().decode(BackupSnapshot.self, from: data) {
                return snapshot
            }
        }
        return nil
    }

    /// Filenames that must never be deleted by rotating backup prune.
    static func isProtectedMigrationBackupFileName(_ fileName: String) -> Bool {
        if fileName == preV4BackupFileName || fileName == preV3BackupFileName { return true }
        if fileName == "pre_v2_latest.json" { return true }
        if fileName.hasPrefix("pre_v2_") { return true }
        if fileName == WorkoutUnifiedSlotsMigration.latestPreMigrationBackupFileName { return true }
        if fileName == CardioSchemaMigration.latestPreMigrationBackupFileName { return true }
        return false
    }

    static func latestBackupURL() -> URL? {
        let url = backupDir.appending(path: "pre_v2_latest.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Pre-V4 backup I/O

    static let preV4BackupFileName = "pre_v4_latest.json"

    static func writePreV4Backup(_ snapshot: BackupSnapshot) throws {
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        let url = backupDir.appending(path: preV4BackupFileName)
        try data.write(to: url, options: .atomic)
    }

    static func readLatestPreV4Backup() -> BackupSnapshot? {
        let url = backupDir.appending(path: preV4BackupFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BackupSnapshot.self, from: data)
    }

    // MARK: - Pre-V3 backup I/O

    static let preV3BackupFileName = "pre_v3_latest.json"

    static func writePreV3Backup(_ snapshot: BackupSnapshot) throws {
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        let url = backupDir.appending(path: preV3BackupFileName)
        try data.write(to: url, options: .atomic)
    }

    static func readLatestPreV3Backup() -> BackupSnapshot? {
        let url = backupDir.appending(path: preV3BackupFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BackupSnapshot.self, from: data)
    }
}

// MARK: - Migration errors

enum FitLogMigrationError: LocalizedError {
    case backupNotFound
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "Pre-migration backup not found. Cannot complete schema migration safely."
        case .decodingFailed(let detail):
            return "V2 migration decoding failed: \(detail)"
        }
    }
}
