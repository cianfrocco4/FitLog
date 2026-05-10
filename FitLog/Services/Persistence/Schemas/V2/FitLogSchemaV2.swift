//
//  FitLogSchemaV2.swift
//  FitLog
//
//  Aggregates all V2 @Model types under a VersionedSchema namespace.
//

import SwiftData

/// Current V2 schema (must be opened with `Schema(versionedSchema: FitLogSchemaV2.self)` when using `SchemaMigrationPlan`).
///
/// **Migration policy:** Keep `versionIdentifier` at `2.0.1` until `FitLogMigrationPlan` defines an explicit
/// lightweight (or custom) stage from a frozen prior `VersionedSchema` to a newer one. Bumping this
/// alone breaks existing stores: the plan only covers V1→V2, so a 2.0.1→2.x jump makes `ModelContainer`
/// fail to open and the app can fall back to an empty in-memory store. Additive `@Model` types (e.g.
/// `SDDynamicProgramV2`) are merged via automatic lightweight migration at the same version.
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

            // Dynamic periodized program (JSON blob)
            SDDynamicProgramV2.self,
        ]
    }
}
