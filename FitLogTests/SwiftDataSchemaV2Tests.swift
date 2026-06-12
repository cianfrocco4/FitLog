//
//  SwiftDataSchemaV2Tests.swift
//  FitLogTests
//
//  Guards against SwiftData schema load failures (e.g. loadIssueModelContainer) at CI time.
//

import SwiftData
import Testing
@testable import FitLog

struct SwiftDataSchemaV2Tests {

    @Test func frozenSchemaV2_loadsInMemoryModelContainer() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.count >= FitLogSchemaV2.models.count)
    }

    @Test func liveSchemaV5_loadsInMemoryModelContainer() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.count >= FitLogSchemaV5.models.count)
    }
}
