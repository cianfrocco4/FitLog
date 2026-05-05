//
//  SDWorkoutExerciseRowV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutExerciseRowV2 {
    var rowId: UUID = UUID()
    var orderIndex: Int = 0
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    var defaultRestTime: Int = 90
    /// Encoded `[String]` — sparse configuration field names.
    var configurationFieldsData: Data = Data()
    /// Encoded `[[String: String]]` — per-set default configuration.
    var recommendedConfigBySetData: Data = Data()
    /// "concrete" or "flexible"
    var resolutionTypeRaw: String = "flexible"
    /// JSON-encoded `ExerciseSnapshot` (only when `resolutionTypeRaw == "concrete"`).
    var concreteSnapshotData: Data?
    var orderInSupersetGroup: Int = 0

    var workout: SDWorkoutV2?

    @Relationship(deleteRule: .cascade)
    var slot: SDSlotBlueprintV2?

    @Relationship(deleteRule: .nullify)
    var defaultExercise: SDExerciseV2?

    @Relationship(deleteRule: .nullify)
    var supersetGroup: SDSupersetGroupV2?

    init() {}

    init(
        rowId: UUID,
        orderIndex: Int,
        recommendedSets: Int,
        recommendedReps: String,
        defaultRestTime: Int,
        configurationFieldsData: Data,
        recommendedConfigBySetData: Data,
        resolutionTypeRaw: String,
        concreteSnapshotData: Data?
    ) {
        self.rowId = rowId
        self.orderIndex = orderIndex
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.defaultRestTime = defaultRestTime
        self.configurationFieldsData = configurationFieldsData
        self.recommendedConfigBySetData = recommendedConfigBySetData
        self.resolutionTypeRaw = resolutionTypeRaw
        self.concreteSnapshotData = concreteSnapshotData
    }

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
            recommendedConfigBySet: configBySet
        )
    }

    static func from(_ we: WorkoutExercise, orderIndex: Int) -> SDWorkoutExerciseRowV2 {
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

        let row = SDWorkoutExerciseRowV2(
            rowId: we.id,
            orderIndex: orderIndex,
            recommendedSets: we.recommendedSets,
            recommendedReps: we.recommendedReps,
            defaultRestTime: we.defaultRestTime,
            configurationFieldsData: configData,
            recommendedConfigBySetData: configBySetData,
            resolutionTypeRaw: resType,
            concreteSnapshotData: snapshotData
        )

        if case .flexible(let b) = we.resolution {
            row.slot = SDSlotBlueprintV2.from(b)
        }

        return row
    }
}
