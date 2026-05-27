//
//  V3MigrationDecoder.swift
//  FitLog
//
//  Reads a BackupSnapshot and inserts the equivalent FitLogSchemaV3 graph.
//

import Foundation
import SwiftData
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "V3MigrationDecoder"
)

enum V3MigrationDecoder {

    static func decode(snapshot: BackupSnapshot, into context: ModelContext) throws {
        log.notice("V3 migration: starting decode (exercises=\(snapshot.exercises.count), workouts=\(snapshot.workouts.count), sessions=\(snapshot.sessions.count))")

        var exerciseMap: [UUID: SDExerciseV3] = [:]
        for ex in snapshot.exercises {
            let sdEx = V3EntityFactory.exercise(from: ex)
            context.insert(sdEx)
            exerciseMap[ex.id] = sdEx
        }

        for (idStr, name) in snapshot.displayNames {
            guard let id = UUID(uuidString: idStr) else { continue }
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let dn = SDExerciseDisplayNameV3(exerciseId: id, customName: t)
            dn.exercise = exerciseMap[id]
            context.insert(dn)
        }

        var workoutMap: [UUID: SDWorkoutV3] = [:]
        for (i, w) in snapshot.workouts.enumerated() {
            let sdW = V3EntityFactory.workout(from: w, sortOrder: i)
            context.insert(sdW)
            workoutMap[w.id] = sdW
            for row in sdW.rows {
                if let defId = row.slot?.defaultExerciseId, let sdEx = exerciseMap[defId] {
                    row.defaultExercise = sdEx
                }
            }
        }

        var sessionCount = 0
        for s in snapshot.sessions {
            let sdS = V3EntityFactory.session(from: s)
            sdS.workout = workoutMap[s.workout.id]
            context.insert(sdS)
            for logRow in sdS.logs {
                if let eid = logRow.exerciseIdSnapshot, let sdEx = exerciseMap[eid] {
                    logRow.exercise = sdEx
                }
            }
            sessionCount += 1
        }

        let sdProgram = V3EntityFactory.program(from: snapshot.program)
        context.insert(sdProgram)
        for entry in sdProgram.cycleEntries {
            entry.referencedWorkout = workoutMap[entry.workoutId]
        }

        MigrationSnapshotExtras.insertExtendedSnapshotData(snapshot, into: context)

        let existingPRs = try context.fetch(FetchDescriptor<SDPersonalRecordV2>())
        if snapshot.personalRecords.isEmpty && existingPRs.isEmpty {
            let prRows = V2MigrationDecoder.buildPRRowsForMigration(sessions: snapshot.sessions)
            for pr in prRows {
                context.insert(pr)
            }
        }

        try context.save()

        log.notice("V3 migration: complete (exercises=\(exerciseMap.count), workouts=\(workoutMap.count), sessions=\(sessionCount))")
    }
}

// MARK: - V3 entity factories

private enum V3EntityFactory {

    static func exercise(from e: Exercise) -> SDExerciseV3 {
        SDExerciseV3(
            exerciseId: e.id,
            name: e.name,
            exerciseDescription: e.description,
            targetedMusclesData: versionedEncode(e.targetedMuscles.map(\.rawValue)),
            isCustom: e.isCustom,
            configurationOptionsData: versionedEncode(e.configurationOptions),
            exerciseRoleRaw: e.exerciseRole.rawValue,
            movementPatternRaw: e.movementPattern?.rawValue
        )
    }

    static func workout(from w: Workout, sortOrder: Int) -> SDWorkoutV3 {
        let sd = SDWorkoutV3(workoutId: w.id, name: w.name, sortOrder: sortOrder)
        sd.rows = w.exercises.enumerated().map { idx, we in
            workoutExerciseRow(from: we, orderIndex: idx)
        }
        if !w.templateSlotIdByWorkoutExerciseId.isEmpty {
            sd.templateSlotBindingsData = versionedEncode(w.templateSlotIdByWorkoutExerciseId)
        }
        return sd
    }

    static func workoutExerciseRow(from we: WorkoutExercise, orderIndex: Int) -> SDWorkoutExerciseRowV3 {
        let configData = versionedEncode(we.configurationFields)
        let configBySetData = versionedEncode(we.recommendedConfigBySet)

        var snapshotData: Data?
        var resType = "flexible"

        switch we.resolution {
        case .concrete(let snap):
            resType = "concrete"
            snapshotData = versionedEncode(snap)
        case .flexible:
            resType = "flexible"
        }

        let row = SDWorkoutExerciseRowV3()
        row.rowId = we.id
        row.orderIndex = orderIndex
        row.recommendedSets = we.recommendedSets
        row.recommendedReps = we.recommendedReps
        row.defaultRestTime = we.defaultRestTime
        row.configurationFieldsData = configData
        row.recommendedConfigBySetData = configBySetData
        row.resolutionTypeRaw = resType
        row.concreteSnapshotData = snapshotData

        if case .flexible(let b) = we.resolution {
            row.slot = slotBlueprint(from: b)
        }

        return row
    }

    static func slotBlueprint(from b: SlotBlueprint) -> SDSlotBlueprintV3 {
        SDSlotBlueprintV3(
            blueprintId: b.id,
            label: b.label,
            targetedMusclesData: versionedEncode(b.targetedMuscles.map(\.rawValue)),
            exerciseRoleRaw: b.exerciseRole?.rawValue,
            movementPatternRaw: b.movementPattern?.rawValue,
            defaultExerciseId: b.defaultExerciseId,
            defaultRestTime: b.defaultRestTime,
            recommendedSets: b.recommendedSets,
            recommendedReps: b.recommendedReps
        )
    }

    static func session(from s: WorkoutSession) -> SDWorkoutSessionV3 {
        let sd = SDWorkoutSessionV3()
        sd.sessionId = s.id
        sd.startTime = s.startTime
        sd.endTime = s.endTime
        sd.sessionNotes = s.sessionNotes
        sd.workoutSnapshotData = versionedEncode(s.workout)
        sd.activeExerciseIdsData = versionedEncode(s.activeExerciseIds)
        sd.completedExerciseIdsData = versionedEncode(s.completedExerciseIds)
        sd.planOriginData = s.sessionPlanOrigin.map { versionedEncode($0) }
        sd.logs = s.exerciseLogs.enumerated().map { idx, log in
            exerciseLog(from: log, orderIndex: idx)
        }
        return sd
    }

    static func exerciseLog(from log: ExerciseLog, orderIndex: Int) -> SDExerciseLogV3 {
        let weData = versionedEncode(log.workoutExercise)
        let nameSnap: String
        let slotLabel: String
        let exerciseId: UUID?

        switch log.workoutExercise.resolution {
        case .concrete(let snap):
            nameSnap = snap.nameAtTimeOfLog
            slotLabel = ""
            exerciseId = snap.exerciseId
        case .flexible(let b):
            nameSnap = b.label
            slotLabel = b.label
            exerciseId = b.defaultExerciseId
        }

        let sd = SDExerciseLogV3()
        sd.logId = log.id
        sd.orderIndex = orderIndex
        sd.notes = log.notes
        sd.sessionRestOverrideSeconds = log.sessionRestOverrideSeconds
        sd.nameSnapshot = nameSnap
        sd.slotLabelSnapshot = slotLabel
        sd.exerciseIdSnapshot = exerciseId
        sd.workoutExerciseData = weData
        sd.sets = log.loggedSets.enumerated().map { idx, set in
            loggedSet(from: set, orderIndex: idx)
        }
        return sd
    }

    static func loggedSet(from s: LoggedSet, orderIndex: Int) -> SDLoggedSetV3 {
        let configData = s.configuration.isEmpty ? Data() : versionedEncode(s.configuration)
        let sd = SDLoggedSetV3()
        sd.setId = s.id
        sd.orderIndex = orderIndex
        sd.weight = s.weight
        sd.reps = s.reps
        sd.restTime = s.restTime
        sd.timestamp = s.timestamp
        sd.setTypeRaw = s.setType.rawValue
        sd.rpe = s.rpe
        sd.configurationData = configData
        sd.dropSegments = s.dropSegments.enumerated().map { idx, seg in
            dropSegment(from: seg, orderIndex: idx)
        }
        return sd
    }

    static func dropSegment(from seg: DropSetSegment, orderIndex: Int) -> SDDropSegmentV3 {
        let sd = SDDropSegmentV3()
        sd.orderIndex = orderIndex
        sd.weight = seg.weight
        sd.reps = seg.reps
        return sd
    }

    static func program(from p: TrainingProgramState) -> SDTrainingProgramV3 {
        let sd = SDTrainingProgramV3()
        sd.sessionsPerWeek = p.sessionsPerWeek
        sd.preferredWeekdaysData = versionedEncode(p.preferredWeekdays)
        sd.anchorDayKey = p.anchorDayKey
        sd.cyclePhaseOffset = p.cyclePhaseOffset
        sd.skippedCycleTrainingDayKeysData = versionedEncode(p.skippedCycleTrainingDayKeys)
        sd.cycleEntries = p.cycleEntries.enumerated().map { idx, ref in
            SDProgramCycleEntryV3(orderIndex: idx, workoutId: ref.libraryWorkoutId)
        }
        sd.frozenDays = p.frozenCalendarDays.map { key, day in
            frozenPlanDay(key: key, day: day)
        }
        sd.dayOverrides = p.dayOverrides.map { key, override in
            dayOverride(key: key, override: override)
        }
        sd.weekOverrides = p.weekOverrides.map { key, override in
            weekOverride(key: key, override: override)
        }
        return sd
    }

    static func frozenPlanDay(key: String, day: FrozenPlanDay) -> SDFrozenPlanDayV3 {
        let sd = SDFrozenPlanDayV3()
        sd.dayKey = key
        sd.kindRaw = day.kind.rawValue
        sd.workoutRefData = day.workoutRef.map { versionedEncode($0) }
        return sd
    }

    static func dayOverride(key: String, override: ScheduleDayOverride) -> SDDayOverrideV3 {
        let sd = SDDayOverrideV3()
        sd.dayKey = key
        sd.intentRaw = override.intent.rawValue
        sd.planRefData = override.planRef.map { versionedEncode($0) }
        return sd
    }

    static func weekOverride(key: String, override: ScheduleWeekOverride) -> SDWeekOverrideV3 {
        let sd = SDWeekOverrideV3()
        sd.weekKey = key
        sd.weekdayOverridesData = versionedEncode(override.weekdayOverrides)
        return sd
    }
}
