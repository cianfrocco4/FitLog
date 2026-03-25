//
//  SwiftDataModels.swift
//  FitLog
//
//  SwiftData persistence layer. Each @Model class mirrors a Codable struct
//  from Models.swift / TrainingScheduleModels.swift. Complex nested value
//  types are stored as JSON Data blobs; scalar fields that need querying
//  are stored natively.
//

import Foundation
import SwiftData

// MARK: - Schema versioning

/// Wraps any Codable payload with an integer version tag so future schema
/// changes can be detected and migrated instead of silently falling back.
struct VersionedPayload<T: Codable>: Codable {
    let schemaVersion: Int
    let data: T
}

/// Bump this when the JSON shape of any persisted blob changes.
/// The version history:
///   1 – initial SwiftData migration (ExerciseSnapshot, SlotResolution, WorkoutPlanRef cycle entries)
let currentSchemaVersion = 1

/// Encode a value wrapped in a VersionedPayload.
func versionedEncode<T: Codable>(_ value: T) -> Data {
    let payload = VersionedPayload(schemaVersion: currentSchemaVersion, data: value)
    return (try? JSONEncoder().encode(payload)) ?? Data()
}

/// Decode a value, handling both versioned and pre-versioned (raw) formats.
/// Returns nil only if both attempts fail.
func versionedDecode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
    if let versioned = try? JSONDecoder().decode(VersionedPayload<T>.self, from: data) {
        // Future: switch on versioned.schemaVersion to apply migrations
        return versioned.data
    }
    // Pre-versioning legacy data — decode directly
    return try? JSONDecoder().decode(T.self, from: data)
}

// MARK: - Full-app backup snapshot

struct BackupSnapshot: Codable {
    let schemaVersion: Int
    let exercises: [Exercise]
    let workouts: [Workout]
    let templates: [WorkoutTemplate]
    let sessions: [WorkoutSession]
    let program: TrainingProgramState
    /// Display names keyed by exercise UUID string.
    let displayNames: [String: String]

    init(schemaVersion: Int, exercises: [Exercise], workouts: [Workout], templates: [WorkoutTemplate], sessions: [WorkoutSession], program: TrainingProgramState, displayNames: [UUID: String]) {
        self.schemaVersion = schemaVersion
        self.exercises = exercises
        self.workouts = workouts
        self.templates = templates
        self.sessions = sessions
        self.program = program
        self.displayNames = Dictionary(uniqueKeysWithValues: displayNames.map { ($0.key.uuidString, $0.value) })
    }
}

// MARK: - Exercise

@Model
final class SDExercise {
    var exerciseId: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var targetedMusclesData: Data = Data()
    var isCustom: Bool = false
    var configurationOptionsData: Data = Data()
    var exerciseRoleRaw: String = "Accessory"
    var movementPatternRaw: String?

    init() {}

    init(exerciseId: UUID, name: String, exerciseDescription: String, targetedMusclesData: Data, isCustom: Bool, configurationOptionsData: Data, exerciseRoleRaw: String, movementPatternRaw: String?) {
        self.exerciseId = exerciseId
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.targetedMusclesData = targetedMusclesData
        self.isCustom = isCustom
        self.configurationOptionsData = configurationOptionsData
        self.exerciseRoleRaw = exerciseRoleRaw
        self.movementPatternRaw = movementPatternRaw
    }

    func toStruct() -> Exercise {
        let muscleStrings = versionedDecode([String].self, from: targetedMusclesData) ?? []
        let muscles = muscleStrings.map { MuscleGroup(rawValue: $0) ?? .other }
        let config = versionedDecode([ExerciseConfigurationOption].self, from: configurationOptionsData) ?? []
        let role = ExerciseRole(rawValue: exerciseRoleRaw) ?? .accessory
        let pattern = movementPatternRaw.flatMap { MovementPattern(rawValue: $0) }
        return Exercise(
            id: exerciseId, name: name, description: exerciseDescription,
            targetedMuscles: muscles, isCustom: isCustom,
            configurationOptions: config, exerciseRole: role, movementPattern: pattern
        )
    }

    static func from(_ e: Exercise) -> SDExercise {
        let musclesData = versionedEncode(e.targetedMuscles.map(\.rawValue))
        let configData = versionedEncode(e.configurationOptions)
        return SDExercise(
            exerciseId: e.id, name: e.name, exerciseDescription: e.description,
            targetedMusclesData: musclesData,
            isCustom: e.isCustom, configurationOptionsData: configData,
            exerciseRoleRaw: e.exerciseRole.rawValue,
            movementPatternRaw: e.movementPattern?.rawValue
        )
    }
}

// MARK: - Workout

@Model
final class SDWorkout {
    var workoutId: UUID = UUID()
    var name: String = ""
    var exercisesData: Data = Data()
    var sortOrder: Int = 0

    init() {}

    init(workoutId: UUID, name: String, exercisesData: Data, sortOrder: Int) {
        self.workoutId = workoutId
        self.name = name
        self.exercisesData = exercisesData
        self.sortOrder = sortOrder
    }

    func toStruct() -> Workout {
        let exercises = versionedDecode([WorkoutExercise].self, from: exercisesData) ?? []
        return Workout(id: workoutId, name: name, exercises: exercises)
    }

    static func from(_ w: Workout, sortOrder: Int) -> SDWorkout {
        let data = versionedEncode(w.exercises)
        return SDWorkout(workoutId: w.id, name: w.name, exercisesData: data, sortOrder: sortOrder)
    }
}

// MARK: - WorkoutTemplate

@Model
final class SDWorkoutTemplate {
    var templateId: UUID = UUID()
    var name: String = ""
    var slotsData: Data = Data()
    var sortOrder: Int = 0

    init() {}

    init(templateId: UUID, name: String, slotsData: Data, sortOrder: Int) {
        self.templateId = templateId
        self.name = name
        self.slotsData = slotsData
        self.sortOrder = sortOrder
    }

    func toStruct() -> WorkoutTemplate {
        let slots = versionedDecode([TemplateSlot].self, from: slotsData) ?? []
        return WorkoutTemplate(id: templateId, name: name, slots: slots)
    }

    static func from(_ t: WorkoutTemplate, sortOrder: Int) -> SDWorkoutTemplate {
        let data = versionedEncode(t.slots)
        return SDWorkoutTemplate(templateId: t.id, name: t.name, slotsData: data, sortOrder: sortOrder)
    }
}

// MARK: - WorkoutSession

@Model
final class SDWorkoutSession {
    var sessionId: UUID = UUID()
    var workoutData: Data = Data()
    var startTime: Date = Date()
    var endTime: Date?
    var exerciseLogsData: Data = Data()
    var activeExerciseIdsData: Data = Data()
    var completedExerciseIdsData: Data = Data()
    var sessionPlanOriginData: Data?

    init() {}

    init(sessionId: UUID, workoutData: Data, startTime: Date, endTime: Date?, exerciseLogsData: Data, activeExerciseIdsData: Data, completedExerciseIdsData: Data, sessionPlanOriginData: Data?) {
        self.sessionId = sessionId
        self.workoutData = workoutData
        self.startTime = startTime
        self.endTime = endTime
        self.exerciseLogsData = exerciseLogsData
        self.activeExerciseIdsData = activeExerciseIdsData
        self.completedExerciseIdsData = completedExerciseIdsData
        self.sessionPlanOriginData = sessionPlanOriginData
    }

    func toStruct() -> WorkoutSession? {
        guard let workout = versionedDecode(Workout.self, from: workoutData),
              let logs = versionedDecode([ExerciseLog].self, from: exerciseLogsData) else {
            return nil
        }
        let activeIds = versionedDecode([UUID].self, from: activeExerciseIdsData) ?? []
        let completedIds = versionedDecode([UUID].self, from: completedExerciseIdsData) ?? []
        let origin = sessionPlanOriginData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return WorkoutSession(
            id: sessionId, workout: workout, startTime: startTime, endTime: endTime,
            exerciseLogs: logs, activeExerciseIds: activeIds,
            completedExerciseIds: completedIds, sessionPlanOrigin: origin
        )
    }

    static func from(_ s: WorkoutSession) -> SDWorkoutSession {
        let wData = versionedEncode(s.workout)
        let logsData = versionedEncode(s.exerciseLogs)
        let activeData = versionedEncode(s.activeExerciseIds)
        let completedData = versionedEncode(s.completedExerciseIds)
        let originData = s.sessionPlanOrigin.map { versionedEncode($0) }
        return SDWorkoutSession(
            sessionId: s.id, workoutData: wData, startTime: s.startTime, endTime: s.endTime,
            exerciseLogsData: logsData, activeExerciseIdsData: activeData,
            completedExerciseIdsData: completedData, sessionPlanOriginData: originData
        )
    }
}

// MARK: - TrainingProgram (singleton row)

@Model
final class SDTrainingProgram {
    var programData: Data = Data()

    init() {}

    init(programData: Data) {
        self.programData = programData
    }

    func toStruct() -> TrainingProgramState? {
        versionedDecode(TrainingProgramState.self, from: programData)
    }

    static func from(_ p: TrainingProgramState) -> SDTrainingProgram {
        let data = versionedEncode(p)
        return SDTrainingProgram(programData: data)
    }
}

// MARK: - ExerciseDisplayName

@Model
final class SDExerciseDisplayName {
    var exerciseId: UUID = UUID()
    var customName: String = ""

    init() {}

    init(exerciseId: UUID, customName: String) {
        self.exerciseId = exerciseId
        self.customName = customName
    }
}
