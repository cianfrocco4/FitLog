//
//  SDWorkoutExerciseRowV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutExerciseRowV3 {
    var rowId: UUID = UUID()
    var orderIndex: Int = 0
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    var defaultRestTime: Int = 90
    var configurationFieldsData: Data = Data()
    var recommendedConfigBySetData: Data = Data()
    var resolutionTypeRaw: String = "flexible"
    var concreteSnapshotData: Data?
    var orderInSupersetGroup: Int = 0

    var workout: SDWorkoutV3?

    @Relationship(deleteRule: .cascade, inverse: \SDSlotBlueprintV3.exerciseRow)
    var slot: SDSlotBlueprintV3?

    var defaultExercise: SDExerciseV3?

    var supersetGroup: SDSupersetGroupV3?

    init() {}

    func toDomain() -> WorkoutExercise {
        let configFields = versionedDecode([String].self, from: configurationFieldsData) ?? []
        let configBySet = versionedDecode([[String: String]].self, from: recommendedConfigBySetData) ?? []

        let resolution: SlotResolution
        if resolutionTypeRaw == "concrete", let snapData = concreteSnapshotData,
           let snap = versionedDecode(ExerciseSnapshot.self, from: snapData) {
            resolution = .concrete(snap)
        } else if let s = slot {
            resolution = .flexible(s.toDomain())
        } else {
            resolution = .flexible(SlotBlueprint(id: UUID(), label: "", targetedMuscles: []))
        }

        return WorkoutExercise(
            id: rowId,
            resolution: resolution,
            defaultRestTime: defaultRestTime,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            configurationFields: configFields,
            recommendedConfigBySet: configBySet,
            cardioPrescription: nil
        )
    }
}
