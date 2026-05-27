//
//  FitLogSchemaV2.swift
//  FitLog
//
//  Aggregates all V2 @Model types under a VersionedSchema namespace.
//

import SwiftData

/// **Frozen** V2 schema at `2.0.1` — matches stores shipped from `main` before dynamic programs.
/// Live app code opens `FitLogSchemaV4` with `FitLogMigrationPlan` (custom V2→V3→V4 chain).
/// Do not add new `@Model` types here; add them on V3+ and extend the migration plan instead.
///
/// `versionIdentifier` must not change: `FitLogMigrationPlan` stages reference this version.
enum FitLogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 1) }

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
