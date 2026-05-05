//
//  FitLogSchemaV2.swift
//  FitLog
//
//  Aggregates all V2 @Model types under a VersionedSchema namespace.
//

import SwiftData

enum FitLogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            // Exercise library
            SDExerciseV2.self,
            SDExerciseDisplayNameV2.self,

            // Workout library
            SDWorkoutV2.self,
            SDWorkoutExerciseRowV2.self,
            SDSlotBlueprintV2.self,
            SDSupersetGroupV2.self,

            // Session history
            SDWorkoutSessionV2.self,
            SDExerciseLogV2.self,
            SDLoggedSetV2.self,
            SDDropSegmentV2.self,

            // Training program
            SDTrainingProgramV2.self,
            SDProgramCycleEntryV2.self,
            SDFrozenPlanDayV2.self,
            SDDayOverrideV2.self,
            SDWeekOverrideV2.self,

            // Split presets (Phase C)
            SDSplitPresetV2.self,
            SDSplitPresetDayV2.self,
            SDSplitPresetSlotV2.self,

            // Personal records
            SDPersonalRecordV2.self,
        ]
    }
}
