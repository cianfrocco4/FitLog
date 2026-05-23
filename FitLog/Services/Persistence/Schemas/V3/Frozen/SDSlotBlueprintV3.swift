//
//  SDSlotBlueprintV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSlotBlueprintV3 {
    var blueprintId: UUID = UUID()
    var label: String = ""
    var targetedMusclesData: Data = Data()
    var exerciseRoleRaw: String?
    var movementPatternRaw: String?
    var defaultExerciseId: UUID?
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"

    var exerciseRow: SDWorkoutExerciseRowV3?

    init() {}

    init(
        blueprintId: UUID,
        label: String,
        targetedMusclesData: Data,
        exerciseRoleRaw: String?,
        movementPatternRaw: String?,
        defaultExerciseId: UUID?,
        defaultRestTime: Int,
        recommendedSets: Int,
        recommendedReps: String
    ) {
        self.blueprintId = blueprintId
        self.label = label
        self.targetedMusclesData = targetedMusclesData
        self.exerciseRoleRaw = exerciseRoleRaw
        self.movementPatternRaw = movementPatternRaw
        self.defaultExerciseId = defaultExerciseId
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
    }

    func toDomain() -> SlotBlueprint {
        let muscleStrings = versionedDecode([String].self, from: targetedMusclesData) ?? []
        let muscles = muscleStrings.map { MuscleGroup(rawValue: $0) ?? .other }
        return SlotBlueprint(
            id: blueprintId,
            label: label,
            targetedMuscles: muscles,
            exerciseRole: exerciseRoleRaw.flatMap { ExerciseRole(rawValue: $0) },
            movementPattern: movementPatternRaw.flatMap { MovementPattern(rawValue: $0) },
            defaultExerciseId: defaultExerciseId,
            defaultRestTime: defaultRestTime,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            cardioPrescription: nil
        )
    }
}
