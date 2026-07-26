//
//  SwiftDataMigrationV5ToV6Tests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct SwiftDataMigrationV5ToV6Tests {

    @Test func diskStore_migratesV5ToV6AndPreservesRows() throws {
        let basename = "FitLogV5V6MigrationTest_\(UUID().uuidString)"
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
            let v5Schema = Schema(versionedSchema: FitLogSchemaV5.self)
            let v5Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let v5Container = try ModelContainer(for: v5Schema, configurations: [v5Config])
            let v5ctx = ModelContext(v5Container)
            let exercise = SDExerciseV2(
                exerciseId: UUID(),
                name: "Bench Press",
                exerciseDescription: "Barbell",
                targetedMusclesData: versionedEncode(["Chest"]),
                isCustom: false,
                configurationOptionsData: Data(),
                exerciseRoleRaw: ExerciseRole.compound.rawValue,
                movementPatternRaw: MovementPattern.horizontalPush.rawValue
            )
            v5ctx.insert(exercise)
            try v5ctx.save()
        }

        let v6Schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let v6Config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let v6Container = try ModelContainer(
            for: v6Schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: [v6Config]
        )
        let v6ctx = ModelContext(v6Container)

        let exercises = try v6ctx.fetch(FetchDescriptor<SDExerciseV2>())
        #expect(exercises.contains { $0.name == "Bench Press" })

        let snapshots = try v6ctx.fetch(FetchDescriptor<SDReadinessSnapshotV6>())
        #expect(snapshots.isEmpty)
    }
}
