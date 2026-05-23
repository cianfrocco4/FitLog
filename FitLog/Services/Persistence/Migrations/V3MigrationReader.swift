//
//  V3MigrationReader.swift
//  FitLog
//
//  Reads a frozen FitLogSchemaV3 store into a BackupSnapshot for V3→V4 custom migration.
//

import Foundation
import SwiftData
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "V3MigrationReader"
)

enum V3MigrationReader {

    static func readSnapshot(from context: ModelContext) throws -> BackupSnapshot {
        let exercises = (try? context.fetch(FetchDescriptor<SDExerciseV3>())) ?? []
        let workouts = (try? context.fetch(FetchDescriptor<SDWorkoutV3>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<SDWorkoutSessionV3>(sortBy: [SortDescriptor(\.startTime)]))) ?? []
        let displayNames = (try? context.fetch(FetchDescriptor<SDExerciseDisplayNameV3>())) ?? []
        let programs = (try? context.fetch(FetchDescriptor<SDTrainingProgramV3>())) ?? []

        let exerciseStructs = exercises.map { $0.toDomain() }
        let workoutStructs = workouts.map { $0.toDomain() }
        let sessionStructs = sessions.compactMap { $0.toDomain() }
        let program = programs.first?.toDomain()
            ?? TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))

        var nameMap: [UUID: String] = [:]
        for dn in displayNames {
            let t = dn.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { nameMap[dn.exerciseId] = t }
        }

        log.notice(
            "V3 snapshot read (exercises=\(exerciseStructs.count), workouts=\(workoutStructs.count), sessions=\(sessionStructs.count))"
        )

        return BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: exerciseStructs,
            workouts: workoutStructs,
            sessions: sessionStructs,
            program: program,
            displayNames: nameMap
        )
    }
}
