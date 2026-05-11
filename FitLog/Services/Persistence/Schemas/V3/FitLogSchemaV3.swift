//
//  FitLogSchemaV3.swift
//  FitLog
//
//  Current live SwiftData schema. Superset of frozen `FitLogSchemaV2` plus additive models.
//

import SwiftData

/// Live schema for the app: open with `Schema(versionedSchema: FitLogSchemaV3.self)` and
/// `migrationPlan: FitLogMigrationPlan.self`. Migrates from frozen V2 via a lightweight stage.
///
/// **Policy:** New `@Model` types or breaking property changes require a new `VersionedSchema`
/// version and an explicit `MigrationStage` in `FitLogMigrationPlan` — do not add models only here
/// while reusing an older `versionIdentifier` on a prior schema enum.
enum FitLogSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

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

            // Dynamic periodized program (JSON blob) — added in V3 lightweight migration
            SDDynamicProgramV2.self,
        ]
    }
}
