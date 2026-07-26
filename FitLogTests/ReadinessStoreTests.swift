//
//  ReadinessStoreTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct ReadinessStoreTests {

    @Test @MainActor func upsertLoadAndTrend_roundTrip() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let store = ReadinessStore(modelContext: context)

        let score = ReadinessScore(
            id: UUID(),
            dayKey: "2026-06-26",
            computedAt: Date(),
            score: 68,
            band: .good,
            summary: "Good readiness",
            components: []
        )
        try store.upsert(score)

        let loaded = store.load(dayKey: "2026-06-26")
        #expect(loaded?.score == 68)
        #expect(loaded?.band == .good)

        let updated = ReadinessScore(
            id: score.id,
            dayKey: "2026-06-26",
            computedAt: Date(),
            score: 74,
            band: .good,
            summary: "Updated readiness",
            components: []
        )
        try store.upsert(updated)
        #expect(store.load(dayKey: "2026-06-26")?.score == 74)

        let day2 = ReadinessScore(
            id: UUID(),
            dayKey: "2026-06-27",
            computedAt: Date(),
            score: 70,
            band: .good,
            summary: "Day 2",
            components: []
        )
        try store.upsert(day2)

        let trend = store.loadTrend(dayKeys: ["2026-06-26", "2026-06-27", "2026-06-28"])
        #expect(trend.count == 2)
        #expect(trend.map(\.dayKey) == ["2026-06-26", "2026-06-27"])
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
