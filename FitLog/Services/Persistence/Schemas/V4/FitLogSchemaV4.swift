//
//  FitLogSchemaV4.swift
//  FitLog
//
//  Live schema for the app: superset of frozen `FitLogSchemaV3` plus additive cardio columns
//  on existing V2 @Model types (`modality`, `cardioMetrics`, `workoutKind`, etc.).
//

import SwiftData

/// Open with `Schema(versionedSchema: FitLogSchemaV4.self)` and `migrationPlan: FitLogMigrationPlan.self`.
/// Migrates from frozen V3 via a custom migration stage in `FitLogMigrationPlan`.
enum FitLogSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDExerciseV2.self,
            SDExerciseDisplayNameV2.self,

            SDWorkoutV2.self,
            SDWorkoutExerciseRowV2.self,
            SDSlotBlueprintV2.self,
            SDSupersetGroupV2.self,

            SDWorkoutSessionV2.self,
            SDExerciseLogV2.self,
            SDLoggedSetV2.self,
            SDDropSegmentV2.self,

            SDTrainingProgramV2.self,
            SDProgramCycleEntryV2.self,
            SDFrozenPlanDayV2.self,
            SDDayOverrideV2.self,
            SDWeekOverrideV2.self,

            SDSplitPresetV2.self,
            SDSplitPresetDayV2.self,
            SDSplitPresetSlotV2.self,

            SDPersonalRecordV2.self,

            SDDynamicProgramV2.self,

            // V4-only: ensures a unique version checksum vs frozen FitLogSchemaV3 (cardio fields alone are lightweight).
            SDSchemaMigrationAnchorV4.self,
        ]
    }
}
