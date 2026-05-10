//
//  FitLogSchemaV1.swift
//  FitLog
//
//  Frozen snapshot of the original six SwiftData models. No model classes are
//  moved here — the schema only references the existing types so SwiftData's
//  SchemaMigrationPlan can declare a valid "from" version.
//

import SwiftData

enum FitLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDExercise.self,
            SDWorkout.self,
            SDWorkoutTemplate.self,
            SDWorkoutSession.self,
            SDTrainingProgram.self,
            SDExerciseDisplayName.self,
        ]
    }
}
