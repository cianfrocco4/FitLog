//
//  FitLogMigrationPlan.swift
//  FitLog
//
//  Custom SwiftData migration from V1 (JSON-blob @Models) to V2 (normalized graph).
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
        [FitLogSchemaV1.self, FitLogSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1ToV2]
    }

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
        let exercises = (try? context.fetch(FetchDescriptor<SDExercise>())) ?? []
        let workouts = (try? context.fetch(FetchDescriptor<SDWorkout>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startTime)]))) ?? []
        let displayNames = (try? context.fetch(FetchDescriptor<SDExerciseDisplayName>())) ?? []
        let programs = (try? context.fetch(FetchDescriptor<SDTrainingProgram>())) ?? []

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

    static let backupDir: URL = URL.applicationSupportDirectory
        .appending(path: "Backups", directoryHint: .isDirectory)

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

    static func latestBackupURL() -> URL? {
        let url = backupDir.appending(path: "pre_v2_latest.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

// MARK: - Migration errors

enum FitLogMigrationError: LocalizedError {
    case backupNotFound
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "Pre-migration backup not found. Cannot complete V2 migration safely."
        case .decodingFailed(let detail):
            return "V2 migration decoding failed: \(detail)"
        }
    }
}
