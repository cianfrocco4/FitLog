//
//  CardioSchemaMigration.swift
//  FitLog
//
//  One-time domain migration after SwiftData V4: writes a pre-cardio backup, ensures
//  legacy strength data carries safe defaults for new cardio fields, and re-saves stores.
//

import Foundation

enum CardioSchemaMigration {
    static let completedUserDefaultsKey = "FitLog.migration.cardio.v1.done"
    static let latestPreMigrationBackupFileName = "pre_cardio_v1_latest.json"

    /// Derives and persists `workoutKind` for library workouts and embedded session snapshots.
    static func normalizeInPlace(
        exercises: [Exercise],
        workouts: inout [Workout],
        sessions: inout [WorkoutSession]
    ) -> Bool {
        var changed = false

        for i in workouts.indices {
            let derived = WorkoutKind.derived(from: workouts[i], exercises: exercises)
            if workouts[i].workoutKind != derived {
                workouts[i].workoutKind = derived
                changed = true
            }
        }

        for i in sessions.indices {
            let derived = WorkoutKind.derived(from: sessions[i].workout, exercises: exercises)
            if sessions[i].workout.workoutKind != derived {
                sessions[i].workout.workoutKind = derived
                changed = true
            }
        }

        return changed
    }

    static func writePreMigrationBackupVerified(_ snapshot: BackupSnapshot) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return false }
        let dir = URL.applicationSupportDirectory.appending(path: "Backups", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return false
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmmss"
        let stampedName = "pre_cardio_v1_\(df.string(from: Date())).json"
        let stampedURL = dir.appending(path: stampedName, directoryHint: .notDirectory)
        let latestURL = dir.appending(path: latestPreMigrationBackupFileName, directoryHint: .notDirectory)
        do {
            try data.write(to: stampedURL, options: .atomic)
        } catch {
            return false
        }
        guard verifyBackupFile(at: stampedURL, snapshot: snapshot) else {
            try? FileManager.default.removeItem(at: stampedURL)
            return false
        }
        do {
            try data.write(to: latestURL, options: .atomic)
        } catch {
            return false
        }
        return verifyBackupFile(at: latestURL, snapshot: snapshot)
    }

    private static func verifyBackupFile(at url: URL, snapshot: BackupSnapshot) -> Bool {
        guard let diskData = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(BackupSnapshot.self, from: diskData) else {
            return false
        }
        return decoded.workouts.count == snapshot.workouts.count
            && decoded.exercises.count == snapshot.exercises.count
            && decoded.sessions.count == snapshot.sessions.count
    }

    static func validateFullSnapshotCodableRoundTrip(_ snapshot: BackupSnapshot) -> Bool {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(snapshot),
              let decoded = try? decoder.decode(BackupSnapshot.self, from: data)
        else { return false }
        return decoded.workouts.count == snapshot.workouts.count
            && decoded.exercises.count == snapshot.exercises.count
            && decoded.sessions.count == snapshot.sessions.count
    }
}
