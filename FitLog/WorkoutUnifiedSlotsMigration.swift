//
//  WorkoutUnifiedSlotsMigration.swift
//  FitLog
//
//  One-time migration: library workout rows that used `.concrete` become `.flexible`
//  SlotBlueprint rows with `defaultExerciseId` (same UX as before, unified slot model).
//

import Foundation

enum WorkoutUnifiedSlotsMigration {
    /// Set after a successful run so we do not re-scan every launch.
    static let completedUserDefaultsKey = "FitLog.migration.unifiedSlotWorkouts.v1.done"

    /// Stable filename for support: most recent pre-migration export before unified slots run.
    static let latestPreMigrationBackupFileName = "pre_unified_slots_latest.json"

    /// True if any exercise row in the embedded workout snapshot still uses `.concrete` (library or historical session).
    static func embeddedWorkoutHasConcreteRow(_ workout: Workout) -> Bool {
        workout.exercises.contains { we in
            if case .concrete = we.resolution { return true }
            return false
        }
    }

    /// Converts concrete rows in a **session’s** embedded workout to flexible blueprints and syncs `exerciseLogs[].workoutExercise` by row id.
    static func migrateSessionConcreteSnapshotInPlace(_ session: inout WorkoutSession, globalExercises: [Exercise]) -> Bool {
        var arr = [session.workout]
        let changed = migrateWorkoutsInPlace(&arr, globalExercises: globalExercises)
        guard changed, let migratedWorkout = arr.first else { return false }
        session.workout = migratedWorkout
        let byId = Dictionary(uniqueKeysWithValues: migratedWorkout.exercises.map { ($0.id, $0) })
        for i in session.exerciseLogs.indices {
            let lid = session.exerciseLogs[i].workoutExercise.id
            if let row = byId[lid] {
                session.exerciseLogs[i].workoutExercise = row
            }
        }
        return true
    }

    /// Migrates every session whose embedded workout still has concrete rows (historical workouts before unified slots).
    static func migrateAllSessionsConcreteSnapshotsInPlace(_ sessions: inout [WorkoutSession], globalExercises: [Exercise]) -> Bool {
        var any = false
        for i in sessions.indices {
            guard embeddedWorkoutHasConcreteRow(sessions[i].workout) else { continue }
            var s = sessions[i]
            if migrateSessionConcreteSnapshotInPlace(&s, globalExercises: globalExercises) {
                sessions[i] = s
                any = true
            }
        }
        return any
    }

    /// Converts concrete library rows to flexible blueprints with defaults. Returns whether any workout changed.
    static func migrateWorkoutsInPlace(_ workouts: inout [Workout], globalExercises: [Exercise]) -> Bool {
        var changed = false
        for wi in workouts.indices {
            var slotMap = workouts[wi].templateSlotIdByWorkoutExerciseId
            for ei in workouts[wi].exercises.indices {
                guard case .concrete(let snap) = workouts[wi].exercises[ei].resolution else { continue }

                let slotId = UUID()
                let ex = globalExercises.first { $0.id == snap.exerciseId }
                let rawLabel = ex.map(\.name) ?? snap.nameAtTimeOfLog
                let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                let labelFinal = trimmed.isEmpty ? "Exercise" : trimmed
                let muscles: [MuscleGroup] = {
                    if let m = ex?.targetedMuscles, !m.isEmpty { return m }
                    return [.other]
                }()

                let blueprint = SlotBlueprint(
                    id: slotId,
                    label: labelFinal,
                    targetedMuscles: muscles,
                    exerciseRole: ex?.exerciseRole,
                    movementPattern: ex?.movementPattern,
                    defaultExerciseId: snap.exerciseId,
                    defaultRestTime: workouts[wi].exercises[ei].defaultRestTime,
                    recommendedSets: workouts[wi].exercises[ei].recommendedSets,
                    recommendedReps: workouts[wi].exercises[ei].recommendedReps
                )

                var we = workouts[wi].exercises[ei]
                we.resolution = .flexible(blueprint)
                workouts[wi].exercises[ei] = we
                slotMap[we.id] = slotId
                changed = true
            }
            workouts[wi].templateSlotIdByWorkoutExerciseId = slotMap
        }
        return changed
    }

    /// Writes timestamped + `latest` backup files and verifies JSON round-trip from disk.
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
        let stampedName = "pre_unified_slots_\(df.string(from: Date())).json"
        let stampedURL = dir.appending(path: stampedName, directoryHint: .notDirectory)
        let latestURL = dir.appending(path: latestPreMigrationBackupFileName, directoryHint: .notDirectory)
        do {
            try data.write(to: stampedURL, options: .atomic)
        } catch {
            return false
        }
        guard verifyBackupFile(at: stampedURL, expectedWorkoutCount: snapshot.workouts.count, expectedExerciseCount: snapshot.exercises.count) else {
            try? FileManager.default.removeItem(at: stampedURL)
            return false
        }
        do {
            try data.write(to: latestURL, options: .atomic)
        } catch {
            return false
        }
        guard verifyBackupFile(at: latestURL, expectedWorkoutCount: snapshot.workouts.count, expectedExerciseCount: snapshot.exercises.count) else {
            try? FileManager.default.removeItem(at: latestURL)
            return false
        }
        return true
    }

    /// Reads a file back and decodes counts (ensures testers can recover from a readable export).
    private static func verifyBackupFile(at url: URL, expectedWorkoutCount: Int, expectedExerciseCount: Int) -> Bool {
        guard let diskData = try? Data(contentsOf: url) else { return false }
        guard let decoded = try? JSONDecoder().decode(BackupSnapshot.self, from: diskData) else { return false }
        return decoded.workouts.count == expectedWorkoutCount && decoded.exercises.count == expectedExerciseCount
    }

    /// Verifies that workouts encode (catches impossible states before save).
    static func validateWorkoutsEncode(_ workouts: [Workout]) -> Bool {
        let encoder = JSONEncoder()
        return (try? encoder.encode(workouts)) != nil
    }

    /// JSON encode → decode to catch Codable issues before touching SwiftData.
    static func validateWorkoutsCodableRoundTrip(_ workouts: [Workout]) -> Bool {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(workouts),
              let copy = try? decoder.decode([Workout].self, from: data)
        else { return false }
        guard copy.count == workouts.count else { return false }
        for (a, b) in zip(workouts, copy) {
            guard a.id == b.id, a.exercises.count == b.exercises.count else { return false }
        }
        return true
    }

    /// Ensures the full post-migration snapshot (workouts + sessions + program + exercises) encodes and decodes.
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

    /// After migration, library workouts must not use legacy `.concrete` rows.
    static func libraryHasNoConcreteRows(_ workouts: [Workout]) -> Bool {
        !workouts.contains { w in
            w.exercises.contains { we in
                if case .concrete = we.resolution { return true }
                return false
            }
        }
    }

    /// Ensures migrated sessions still round-trip through JSON (same shape as SwiftData blobs).
    static func validateSessionsCodableRoundTrip(_ sessions: [WorkoutSession]) -> Bool {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(sessions),
              let copy = try? decoder.decode([WorkoutSession].self, from: data)
        else { return false }
        guard copy.count == sessions.count else { return false }
        for (a, b) in zip(sessions, copy) {
            guard a.id == b.id,
                  a.workout.exercises.count == b.workout.exercises.count,
                  a.exerciseLogs.count == b.exerciseLogs.count
            else { return false }
        }
        return true
    }
}
