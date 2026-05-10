//
//  SDExerciseV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDExerciseV2 {
    var exerciseId: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var targetedMusclesData: Data = Data()
    var isCustom: Bool = false
    var configurationOptionsData: Data = Data()
    var exerciseRoleRaw: String = "Accessory"
    var movementPatternRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \SDExerciseDisplayNameV2.exercise)
    var displayName: SDExerciseDisplayNameV2?

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutExerciseRowV2.defaultExercise)
    var rowsWithDefaultExercise: [SDWorkoutExerciseRowV2] = []

    @Relationship(deleteRule: .nullify, inverse: \SDExerciseLogV2.exercise)
    var exerciseLogs: [SDExerciseLogV2] = []

    init() {}

    init(
        exerciseId: UUID,
        name: String,
        exerciseDescription: String,
        targetedMusclesData: Data,
        isCustom: Bool,
        configurationOptionsData: Data,
        exerciseRoleRaw: String,
        movementPatternRaw: String?
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.targetedMusclesData = targetedMusclesData
        self.isCustom = isCustom
        self.configurationOptionsData = configurationOptionsData
        self.exerciseRoleRaw = exerciseRoleRaw
        self.movementPatternRaw = movementPatternRaw
    }

    func toDomain() -> Exercise {
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

    static func from(_ e: Exercise) -> SDExerciseV2 {
        let musclesData = versionedEncode(e.targetedMuscles.map(\.rawValue))
        let configData = versionedEncode(e.configurationOptions)
        return SDExerciseV2(
            exerciseId: e.id, name: e.name, exerciseDescription: e.description,
            targetedMusclesData: musclesData,
            isCustom: e.isCustom, configurationOptionsData: configData,
            exerciseRoleRaw: e.exerciseRole.rawValue,
            movementPatternRaw: e.movementPattern?.rawValue
        )
    }
}
