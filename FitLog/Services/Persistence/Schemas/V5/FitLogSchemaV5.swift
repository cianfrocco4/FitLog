//
//  FitLogSchemaV5.swift
//  FitLog
//
//  Live schema: superset of V4 plus Coach chat persistence models.
//

import SwiftData

/// Open with `Schema(versionedSchema: FitLogSchemaV5.self)` and `migrationPlan: FitLogMigrationPlan.self`.
enum FitLogSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

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

            SDSchemaMigrationAnchorV4.self,

            SDCoachConversationV5.self,
            SDCoachMessageV5.self,
        ]
    }
}
