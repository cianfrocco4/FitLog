//
//  V2MigrationDecoder.swift
//  FitLog
//
//  Reads a BackupSnapshot (written in willMigrate) and inserts the equivalent
//  V2 graph into the provided ModelContext. Called from FitLogMigrationPlan.didMigrate.
//

import Foundation
import SwiftData
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "V2MigrationDecoder"
)

enum V2MigrationDecoder {

    // MARK: - Entry point

    static func decode(snapshot: BackupSnapshot, into context: ModelContext) throws {
        log.notice("V2 migration: starting decode (exercises=\(snapshot.exercises.count), workouts=\(snapshot.workouts.count), sessions=\(snapshot.sessions.count))")

        // 1. Exercises
        var exerciseMap: [UUID: SDExerciseV2] = [:]
        for ex in snapshot.exercises {
            let sdEx = SDExerciseV2.from(ex)
            context.insert(sdEx)
            exerciseMap[ex.id] = sdEx
        }

        // 2. Display names
        for (idStr, name) in snapshot.displayNames {
            guard let id = UUID(uuidString: idStr) else { continue }
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let dn = SDExerciseDisplayNameV2(exerciseId: id, customName: t)
            dn.exercise = exerciseMap[id]
            context.insert(dn)
        }

        // 3. Library workouts
        var workoutMap: [UUID: SDWorkoutV2] = [:]
        for (i, w) in snapshot.workouts.enumerated() {
            let sdW = SDWorkoutV2.from(w, sortOrder: i)
            context.insert(sdW)
            workoutMap[w.id] = sdW
            // Link default exercises on flexible rows
            for row in sdW.rows {
                if let defId = row.slot?.defaultExerciseId, let sdEx = exerciseMap[defId] {
                    row.defaultExercise = sdEx
                }
            }
        }

        // 4. Sessions
        var sessionCount = 0
        for s in snapshot.sessions {
            let sdS = SDWorkoutSessionV2.from(s)
            sdS.workout = workoutMap[s.workout.id]
            context.insert(sdS)
            // Link exercise relationships in logs
            for logRow in sdS.logs {
                if let eid = logRow.exerciseIdSnapshot, let sdEx = exerciseMap[eid] {
                    logRow.exercise = sdEx
                }
            }
            sessionCount += 1
        }

        // 5. Training program
        let sdProgram = SDTrainingProgramV2.from(snapshot.program)
        context.insert(sdProgram)
        // Link cycle entries to library workouts
        for entry in sdProgram.cycleEntries {
            entry.referencedWorkout = workoutMap[entry.workoutId]
        }

        // 6. Extended snapshot data — replace preserved cross-version rows before insert
        try MigrationSnapshotExtras.replaceExtendedSnapshotData(snapshot, into: context)

        // 7. PR backfill — skip when snapshot already has PR rows or store already contains PRs
        let existingPRs = try context.fetch(FetchDescriptor<SDPersonalRecordV2>())
        if snapshot.personalRecords.isEmpty && existingPRs.isEmpty {
            let prRows = buildPRRows(sessions: snapshot.sessions)
            for pr in prRows {
                context.insert(pr)
            }
        }

        try context.save()

        log.notice("V2 migration: complete (exercises=\(exerciseMap.count), workouts=\(workoutMap.count), sessions=\(sessionCount), prs=\(snapshot.personalRecords.count))")
    }

    // MARK: - PR backfill

    static func buildPRRowsForMigration(sessions: [WorkoutSession]) -> [SDPersonalRecordV2] {
        buildPRRows(sessions: sessions)
    }

    private static func buildPRRows(sessions: [WorkoutSession]) -> [SDPersonalRecordV2] {
        // Track per-exercise bests: [exerciseId: [kind: SDPersonalRecordV2]]
        var bestByExerciseAndKind: [UUID: [PRKind: SDPersonalRecordV2]] = [:]

        let sortedSessions = sessions.filter { $0.isCompleted }.sorted { $0.startTime < $1.startTime }

        for session in sortedSessions {
            for log in session.exerciseLogs {
                guard let exerciseId = log.workoutExercise.exerciseId else { continue }
                for set in log.loggedSets {
                    guard set.countsTowardLoadPRMetrics else { continue }

                    let weight = set.weight
                    let reps = set.reps
                    let est1RM = epley1RM(weight: weight, reps: reps)
                    let volume = set.totalVolumeLoad

                    update(
                        &bestByExerciseAndKind,
                        exerciseId: exerciseId,
                        kind: .maxWeight,
                        value: weight,
                        setId: set.id,
                        sessionId: session.id,
                        achievedAt: set.timestamp
                    )
                    update(
                        &bestByExerciseAndKind,
                        exerciseId: exerciseId,
                        kind: .estimatedOneRM,
                        value: est1RM,
                        setId: set.id,
                        sessionId: session.id,
                        achievedAt: set.timestamp
                    )
                    update(
                        &bestByExerciseAndKind,
                        exerciseId: exerciseId,
                        kind: .maxVolume,
                        value: volume,
                        setId: set.id,
                        sessionId: session.id,
                        achievedAt: set.timestamp
                    )
                }
            }
        }

        return bestByExerciseAndKind.values.flatMap { $0.values }
    }

    private static func update(
        _ map: inout [UUID: [PRKind: SDPersonalRecordV2]],
        exerciseId: UUID,
        kind: PRKind,
        value: Double,
        setId: UUID,
        sessionId: UUID,
        achievedAt: Date
    ) {
        guard value > 0 else { return }
        let existing = map[exerciseId]?[kind]
        if existing == nil || value > (existing?.value ?? 0) {
            let pr = SDPersonalRecordV2(
                prId: UUID(),
                exerciseId: exerciseId,
                kindRaw: kind.rawValue,
                value: value,
                setId: setId,
                sessionId: sessionId,
                achievedAt: achievedAt
            )
            map[exerciseId, default: [:]][kind] = pr
        }
    }

    /// Epley formula: 1RM = w × (1 + r/30).
    private static func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
