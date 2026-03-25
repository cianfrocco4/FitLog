//
//  MigrationService.swift
//  FitLog
//
//  One-time migration from UserDefaults to SwiftData. Reads all legacy keys,
//  inserts records into the ModelContext, verifies counts, then cleans up
//  UserDefaults only on success.
//

import Foundation
import SwiftData

enum MigrationService {

    static let migrationFlag = "swiftDataMigrationComplete_v1"

    static var needsMigration: Bool {
        !UserDefaults.standard.bool(forKey: migrationFlag)
    }

    // MARK: - Public entry point

    static func migrateIfNeeded(context: ModelContext) {
        guard needsMigration else { return }

        let hasAnyLegacyData =
            UserDefaults.standard.data(forKey: LegacyKey.workouts) != nil ||
            UserDefaults.standard.data(forKey: LegacyKey.exercises) != nil ||
            UserDefaults.standard.data(forKey: LegacyKey.sessions) != nil ||
            UserDefaults.standard.data(forKey: LegacyKey.templates) != nil ||
            UserDefaults.standard.data(forKey: LegacyKey.program) != nil

        guard hasAnyLegacyData else {
            UserDefaults.standard.set(true, forKey: migrationFlag)
            #if DEBUG
            print("[Migration] No legacy UserDefaults data found — marking complete")
            #endif
            return
        }

        do {
            try performMigration(context: context)
            UserDefaults.standard.set(true, forKey: migrationFlag)
            cleanupLegacyKeys()
            #if DEBUG
            print("[Migration] Success — UserDefaults keys removed")
            #endif
        } catch {
            #if DEBUG
            print("[Migration] FAILED: \(error). UserDefaults left intact for fallback.")
            #endif
        }
    }

    // MARK: - Migration logic

    private static func performMigration(context: ModelContext) throws {
        let exercises = loadLegacy([Exercise].self, key: LegacyKey.exercises, backup: LegacyKey.exercisesBackup)
        let workouts = loadLegacy([Workout].self, key: LegacyKey.workouts, backup: LegacyKey.workoutsBackup)
        let templates = loadLegacy([WorkoutTemplate].self, key: LegacyKey.templates, backup: LegacyKey.templatesBackup)
        let sessions = loadLegacy([WorkoutSession].self, key: LegacyKey.sessions, backup: LegacyKey.sessionsBackup)
        let program = loadLegacy(TrainingProgramState.self, key: LegacyKey.program, backup: nil)
        let displayNames = loadLegacyDisplayNames()

        for ex in exercises {
            context.insert(SDExercise.from(ex))
        }

        for (i, w) in workouts.enumerated() {
            context.insert(SDWorkout.from(w, sortOrder: i))
        }

        for (i, t) in templates.enumerated() {
            context.insert(SDWorkoutTemplate.from(t, sortOrder: i))
        }

        for s in sessions {
            context.insert(SDWorkoutSession.from(s))
        }

        if let p = program {
            context.insert(SDTrainingProgram.from(p))
        }

        for (id, name) in displayNames {
            context.insert(SDExerciseDisplayName(exerciseId: id, customName: name))
        }

        try context.save()

        // Verify counts match exactly
        try verify(context: context, expected: exercises.count, model: SDExercise.self, label: "exercises")
        try verify(context: context, expected: workouts.count, model: SDWorkout.self, label: "workouts")
        try verify(context: context, expected: templates.count, model: SDWorkoutTemplate.self, label: "templates")
        try verify(context: context, expected: sessions.count, model: SDWorkoutSession.self, label: "sessions")
        try verify(context: context, expected: displayNames.count, model: SDExerciseDisplayName.self, label: "displayNames")

        let programCount = (try? context.fetchCount(FetchDescriptor<SDTrainingProgram>())) ?? 0
        let expectedProgramCount = program != nil ? 1 : 0
        guard programCount == expectedProgramCount else {
            throw MigrationError.countMismatch("trainingProgram: expected \(expectedProgramCount), got \(programCount)")
        }
    }

    private static func verify<T: PersistentModel>(context: ModelContext, expected: Int, model: T.Type, label: String) throws {
        let count = (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        guard count == expected else {
            throw MigrationError.countMismatch("\(label): expected \(expected), got \(count)")
        }
    }

    // MARK: - Legacy loading (reuses existing Codable structs)

    private static func loadLegacy<T: Decodable>(_ type: T.Type, key: String, backup: String?) -> T where T: ExpressibleByArrayLiteral {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let bk = backup,
           let data = UserDefaults.standard.data(forKey: bk),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return []
    }

    private static func loadLegacy<T: Decodable>(_ type: T.Type, key: String, backup: String?) -> T? {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let bk = backup,
           let data = UserDefaults.standard.data(forKey: bk),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return nil
    }

    private static func loadLegacyDisplayNames() -> [UUID: String] {
        guard let data = UserDefaults.standard.data(forKey: LegacyKey.displayNames),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        var out: [UUID: String] = [:]
        for (key, value) in raw {
            guard let id = UUID(uuidString: key) else { continue }
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { out[id] = t }
        }
        return out
    }

    // MARK: - Cleanup

    private static func cleanupLegacyKeys() {
        let allKeys = [
            LegacyKey.workouts, LegacyKey.workoutsBackup,
            LegacyKey.templates, LegacyKey.templatesBackup,
            LegacyKey.exercises,
            LegacyKey.displayNames,
            LegacyKey.sessions, LegacyKey.sessionsBackup,
            LegacyKey.program,
            LegacyKey.exercisesPreloaded,
            LegacyKey.schedulePrecheckFlag,
            LegacyKey.workoutsPrecheckSnapshot,
            LegacyKey.sessionsPrecheckSnapshot,
        ]
        for key in allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Key constants (must match old DataManager)

    enum LegacyKey {
        static let workouts = "userWorkouts"
        static let workoutsBackup = "userWorkouts_backup_v1"
        static let templates = "userWorkoutTemplates_v1"
        static let templatesBackup = "userWorkoutTemplates_backup_v1"
        static let exercises = "globalExercises"
        static let exercisesBackup: String? = nil
        static let displayNames = "exerciseLocalDisplayNames"
        static let sessions = "completedSessions"
        static let sessionsBackup = "completedSessions_backup_v1"
        static let exercisesPreloaded = "exercisesPreloaded"
        static let program = "trainingProgram_v1"
        static let schedulePrecheckFlag = "fitlog_schedule_precheck_backup_v1"
        static let workoutsPrecheckSnapshot = "userWorkouts_precheck_schedule_v1"
        static let sessionsPrecheckSnapshot = "completedSessions_precheck_schedule_v1"
    }

    enum MigrationError: Error, LocalizedError {
        case countMismatch(String)

        var errorDescription: String? {
            switch self {
            case .countMismatch(let detail):
                return "Migration count mismatch: \(detail)"
            }
        }
    }
}
