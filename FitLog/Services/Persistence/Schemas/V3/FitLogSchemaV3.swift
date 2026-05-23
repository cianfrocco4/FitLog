//
//  FitLogSchemaV3.swift
//  FitLog
//
//  Frozen schema at 3.0.0 (pre-cardio). Uses V3 @Model types in Frozen/ — distinct checksum from FitLogSchemaV4.
//

import SwiftData

/// Frozen schema for stores at version 3.0.0. App opens `FitLogSchemaV4` with `FitLogMigrationPlan`.
enum FitLogSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDExerciseV3.self,
            SDExerciseDisplayNameV3.self,

            SDWorkoutV3.self,
            SDWorkoutExerciseRowV3.self,
            SDSlotBlueprintV3.self,
            SDSupersetGroupV3.self,

            SDWorkoutSessionV3.self,
            SDExerciseLogV3.self,
            SDLoggedSetV3.self,
            SDDropSegmentV3.self,

            SDTrainingProgramV3.self,
            SDProgramCycleEntryV3.self,
            SDFrozenPlanDayV3.self,
            SDDayOverrideV3.self,
            SDWeekOverrideV3.self,

            SDSplitPresetV2.self,
            SDSplitPresetDayV2.self,
            SDSplitPresetSlotV2.self,

            SDPersonalRecordV2.self,

            SDDynamicProgramV2.self,
        ]
    }
}
