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

    @Test func schemaV2_loadsInMemoryModelContainer() throws {
        let schema = Schema(versionedSchema: FitLogSchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        // One persisted entity per @Model type in FitLogSchemaV2 (SwiftData may add metadata; count should be at least models).
        #expect(container.schema.entities.count >= FitLogSchemaV2.models.count)
    }
}
