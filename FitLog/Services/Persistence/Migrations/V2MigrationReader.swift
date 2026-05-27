//
//  V2MigrationReader.swift
//  FitLog
//
//  Reads a frozen FitLogSchemaV2 store into a BackupSnapshot for V2→V3 custom migration.
//

import Foundation
import SwiftData
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "V2MigrationReader"
)

enum V2MigrationReader {

    static func readSnapshot(from context: ModelContext) throws -> BackupSnapshot {
        let exercises = try context.fetch(FetchDescriptor<SDExerciseV2>())
        let workouts = try context.fetch(FetchDescriptor<SDWorkoutV2>(sortBy: [SortDescriptor(\.sortOrder)]))
        let sessions = try context.fetch(FetchDescriptor<SDWorkoutSessionV2>(sortBy: [SortDescriptor(\.startTime)]))
        let displayNames = try context.fetch(FetchDescriptor<SDExerciseDisplayNameV2>())
        let programs = try context.fetch(FetchDescriptor<SDTrainingProgramV2>())
        let splitPresetRows = try context.fetch(FetchDescriptor<SDSplitPresetV2>())
        let prRows = try context.fetch(FetchDescriptor<SDPersonalRecordV2>())

        let exerciseStructs = exercises.map { $0.toDomain() }
        let workoutStructs = workouts.map { $0.toDomain() }

        var sessionDecodeFailures = 0
        let sessionStructs = sessions.compactMap { row -> WorkoutSession? in
            guard let domain = row.toDomain() else {
                sessionDecodeFailures += 1
                return nil
            }
            return domain
        }

        let program = programs.first?.toDomain()
            ?? TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))

        var nameMap: [UUID: String] = [:]
        for dn in displayNames {
            let t = dn.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { nameMap[dn.exerciseId] = t }
        }

        log.notice(
            "V2 snapshot read (exercises=\(exerciseStructs.count), workouts=\(workoutStructs.count), sessions=\(sessionStructs.count), sessionDecodeFailures=\(sessionDecodeFailures), presets=\(splitPresetRows.count), prs=\(prRows.count))"
        )

        if sessionDecodeFailures > 0 {
            log.error("V2 snapshot dropped \(sessionDecodeFailures) session(s) during toDomain()")
        }

        return BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: exerciseStructs,
            workouts: workoutStructs,
            sessions: sessionStructs,
            program: program,
            displayNames: nameMap,
            dynamicProgram: nil,
            splitPresets: MigrationSnapshotExtras.splitPresets(from: splitPresetRows),
            personalRecords: MigrationSnapshotExtras.personalRecords(from: prRows)
        )
    }
}
