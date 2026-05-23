//
//  SwiftDataMigrationV3ToV4Tests.swift
//  FitLogTests
//
//  Ensures on-disk V3 stores upgrade via custom migration to V4 without data loss.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct SwiftDataMigrationV3ToV4Tests {

    @Test func diskStore_migratesV3ToV4AndPreservesRows() throws {
        let basename = "FitLogV3V4MigrationTest_\(UUID().uuidString)"
        let storeURL = FileManager.default.temporaryDirectory.appending(
            path: "\(basename).store",
            directoryHint: .notDirectory
        )

        func removeArtifacts() {
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: url)
            }
        }

        removeArtifacts()
        defer { removeArtifacts() }

        do {
            let v3Schema = Schema(versionedSchema: FitLogSchemaV3.self)
            let v3Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v3Container = try ModelContainer(for: v3Schema, configurations: [v3Config])
            let v3ctx = ModelContext(v3Container)
            let exercise = SDExerciseV3(
                exerciseId: UUID(),
                name: "Bench Press",
                exerciseDescription: "Flat",
                targetedMusclesData: versionedEncode(["Chest"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.horizontalPush.rawValue
            )
            v3ctx.insert(exercise)
            try v3ctx.save()
        }

        let v4Schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let v4Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v4Container = try ModelContainer(
            for: v4Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v4Config]
        )
        let v4ctx = ModelContext(v4Container)
        let exercises = try v4ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Bench Press" })
        #expect(exercises.first?.modalityRaw == ExerciseModality.strength.rawValue)
        #expect(exercises.first?.cardioMetadataData.isEmpty == true)
        let anchors = try v4ctx.fetch(FetchDescriptor<SDSchemaMigrationAnchorV4>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.schemaVersionMajor == 4)
    }

    @Test func modelContainer_openV4Schema_doesNotDuplicateChecksums() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [config]
        )
        #expect(container.schema.version == Schema.Version(4, 0, 0))
    }
}
