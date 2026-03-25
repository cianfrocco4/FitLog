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
        let muscleStrings = (try? JSONDecoder().decode([String].self, from: targetedMusclesData)) ?? []
        let muscles = muscleStrings.map { MuscleGroup(rawValue: $0) ?? .other }
        let config = (try? JSONDecoder().decode([ExerciseConfigurationOption].self, from: configurationOptionsData)) ?? []
        let role = ExerciseRole(rawValue: exerciseRoleRaw) ?? .accessory
        let pattern = movementPatternRaw.flatMap { MovementPattern(rawValue: $0) }
        return Exercise(
            id: exerciseId, name: name, description: exerciseDescription,
            targetedMuscles: muscles, isCustom: isCustom,
            configurationOptions: config, exerciseRole: role, movementPattern: pattern
        )
    }

    static func from(_ e: Exercise) -> SDExercise {
        let musclesData = (try? JSONEncoder().encode(e.targetedMuscles.map(\.rawValue))) ?? Data()
        let configData = (try? JSONEncoder().encode(e.configurationOptions)) ?? Data()
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
        let exercises = (try? JSONDecoder().decode([WorkoutExercise].self, from: exercisesData)) ?? []
        return Workout(id: workoutId, name: name, exercises: exercises)
    }

    static func from(_ w: Workout, sortOrder: Int) -> SDWorkout {
        let data = (try? JSONEncoder().encode(w.exercises)) ?? Data()
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
        let slots = (try? JSONDecoder().decode([TemplateSlot].self, from: slotsData)) ?? []
        return WorkoutTemplate(id: templateId, name: name, slots: slots)
    }

    static func from(_ t: WorkoutTemplate, sortOrder: Int) -> SDWorkoutTemplate {
        let data = (try? JSONEncoder().encode(t.slots)) ?? Data()
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
        guard let workout = try? JSONDecoder().decode(Workout.self, from: workoutData),
              let logs = try? JSONDecoder().decode([ExerciseLog].self, from: exerciseLogsData) else {
            return nil
        }
        let activeIds = (try? JSONDecoder().decode([UUID].self, from: activeExerciseIdsData)) ?? []
        let completedIds = (try? JSONDecoder().decode([UUID].self, from: completedExerciseIdsData)) ?? []
        let origin = sessionPlanOriginData.flatMap { try? JSONDecoder().decode(WorkoutPlanRef.self, from: $0) }
        return WorkoutSession(
            id: sessionId, workout: workout, startTime: startTime, endTime: endTime,
            exerciseLogs: logs, activeExerciseIds: activeIds,
            completedExerciseIds: completedIds, sessionPlanOrigin: origin
        )
    }

    static func from(_ s: WorkoutSession) -> SDWorkoutSession {
        let wData = (try? JSONEncoder().encode(s.workout)) ?? Data()
        let logsData = (try? JSONEncoder().encode(s.exerciseLogs)) ?? Data()
        let activeData = (try? JSONEncoder().encode(s.activeExerciseIds)) ?? Data()
        let completedData = (try? JSONEncoder().encode(s.completedExerciseIds)) ?? Data()
        let originData = s.sessionPlanOrigin.flatMap { try? JSONEncoder().encode($0) }
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
        try? JSONDecoder().decode(TrainingProgramState.self, from: programData)
    }

    static func from(_ p: TrainingProgramState) -> SDTrainingProgram {
        let data = (try? JSONEncoder().encode(p)) ?? Data()
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
