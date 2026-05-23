//
//  SDExerciseV3.swift
//  FitLog
//
//  Frozen at schema 3.0.0 (pre-cardio). Used only by FitLogSchemaV3 — not the live SDExerciseV2 type.
//

import Foundation
import SwiftData

@Model
final class SDExerciseV3 {
    var exerciseId: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var targetedMusclesData: Data = Data()
    var isCustom: Bool = false
    var configurationOptionsData: Data = Data()
    var exerciseRoleRaw: String = "Accessory"
    var movementPatternRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \SDExerciseDisplayNameV3.exercise)
    var displayName: SDExerciseDisplayNameV3?

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutExerciseRowV3.defaultExercise)
    var rowsWithDefaultExercise: [SDWorkoutExerciseRowV3] = []

    @Relationship(deleteRule: .nullify, inverse: \SDExerciseLogV3.exercise)
    var exerciseLogs: [SDExerciseLogV3] = []

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
            configurationOptions: config, exerciseRole: role, movementPattern: pattern,
            modality: .strength, cardioMetadata: nil
        )
    }
}
