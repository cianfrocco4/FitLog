//
//  ReadinessStore.swift
//  FitLog
//

import Foundation
import SwiftData

@MainActor
final class ReadinessStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func upsert(_ score: ReadinessScore) throws {
        let dayKey = score.dayKey
        let descriptor = FetchDescriptor<SDReadinessSnapshotV6>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        let existing = try modelContext.fetch(descriptor).first
        if let existing {
            existing.computedAt = score.computedAt
            existing.score = score.score
            existing.bandRaw = score.band.rawValue
            existing.summary = score.summary
            existing.componentsData = SDReadinessSnapshotV6.from(score: score).componentsData
        } else {
            modelContext.insert(SDReadinessSnapshotV6.from(score: score))
        }
        try modelContext.save()
    }

    func load(dayKey: String) -> ReadinessScore? {
        let descriptor = FetchDescriptor<SDReadinessSnapshotV6>(
            predicate: #Predicate { $0.dayKey == dayKey },
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor).first)?.toReadinessScore()
    }

    func loadTrend(dayKeys: [String]) -> [ReadinessScore] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<SDReadinessSnapshotV6>(
            sortBy: [SortDescriptor(\.dayKey, order: .forward)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let allowed = Set(dayKeys)
        return all
            .filter { allowed.contains($0.dayKey) }
            .compactMap { $0.toReadinessScore() }
            .sorted { $0.dayKey < $1.dayKey }
    }
}
