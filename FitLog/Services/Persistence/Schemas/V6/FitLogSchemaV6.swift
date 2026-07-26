//
//  FitLogSchemaV6.swift
//  FitLog
//
//  Live schema: V5 superset plus daily readiness snapshots.
//

import SwiftData

enum FitLogSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        FitLogSchemaV5.models + [SDReadinessSnapshotV6.self]
    }
}
