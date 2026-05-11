//
//  SwiftDataMigrationV2ToV3Tests.swift
//  FitLogTests
//
//  Ensures on-disk V2 (frozen 2.0.1) stores upgrade via lightweight migration to V3 without data loss.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct SwiftDataMigrationV2ToV3Tests {

    @Test func diskStore_migratesV2ToV3AndPreservesRows() throws {
        let basename = "FitLogV2V3MigrationTest_\(UUID().uuidString)"
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
            let v2Schema = Schema(versionedSchema: FitLogSchemaV2.self)
            let v2Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v2Container = try ModelContainer(for: v2Schema, configurations: [v2Config])
            let v2ctx = ModelContext(v2Container)
            let preset = SDSplitPresetV2(
                presetId: UUID(),
                name: "MigrationSeed",
                createdAt: Date(),
                notes: "n",
                sessionsPerWeek: 4
            )
            v2ctx.insert(preset)
            try v2ctx.save()
        }

        let v3Schema = Schema(versionedSchema: FitLogSchemaV3.self)
        let v3Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v3Container = try ModelContainer(
            for: v3Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v3Config]
        )
        let v3ctx = ModelContext(v3Container)
        let presets = try v3ctx.fetch(FetchDescriptor<SDSplitPresetV2>())
        #expect(presets.contains { $0.name == "MigrationSeed" })
        let dynamicRows = try v3ctx.fetch(FetchDescriptor<SDDynamicProgramV2>())
        #expect(dynamicRows.isEmpty)
    }
}
