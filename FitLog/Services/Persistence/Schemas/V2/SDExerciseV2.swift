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
    var modalityRaw: String = ExerciseModality.strength.rawValue
    var cardioMetadataData: Data = Data()

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
        movementPatternRaw: String?,
        modalityRaw: String = ExerciseModality.strength.rawValue,
        cardioMetadataData: Data = Data()
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.targetedMusclesData = targetedMusclesData
        self.isCustom = isCustom
        self.configurationOptionsData = configurationOptionsData
        self.exerciseRoleRaw = exerciseRoleRaw
        self.movementPatternRaw = movementPatternRaw
        self.modalityRaw = modalityRaw
        self.cardioMetadataData = cardioMetadataData
    }

    func toDomain() -> Exercise {
        let muscleStrings = versionedDecode([String].self, from: targetedMusclesData) ?? []
        let muscles = muscleStrings.map { MuscleGroup(rawValue: $0) ?? .other }
        let config = versionedDecode([ExerciseConfigurationOption].self, from: configurationOptionsData) ?? []
        let role = ExerciseRole(rawValue: exerciseRoleRaw) ?? .accessory
        let pattern = movementPatternRaw.flatMap { MovementPattern(rawValue: $0) }
        let modality = ExerciseModality(rawValue: modalityRaw) ?? .strength
        let cardioMetadata = versionedDecode(CardioExerciseMetadata.self, from: cardioMetadataData)
        return Exercise(
            id: exerciseId, name: name, description: exerciseDescription,
            targetedMuscles: muscles, isCustom: isCustom,
            configurationOptions: config, exerciseRole: role, movementPattern: pattern,
            modality: modality, cardioMetadata: cardioMetadata
        )
    }

    static func from(_ e: Exercise) -> SDExerciseV2 {
        let musclesData = versionedEncode(e.targetedMuscles.map(\.rawValue))
        let configData = versionedEncode(e.configurationOptions)
        let cardioData = e.cardioMetadata.map { versionedEncode($0) } ?? Data()
        return SDExerciseV2(
            exerciseId: e.id, name: e.name, exerciseDescription: e.description,
            targetedMusclesData: musclesData,
            isCustom: e.isCustom, configurationOptionsData: configData,
            exerciseRoleRaw: e.exerciseRole.rawValue,
            movementPatternRaw: e.movementPattern?.rawValue,
            modalityRaw: e.modality.rawValue,
            cardioMetadataData: cardioData
        )
    }
}
