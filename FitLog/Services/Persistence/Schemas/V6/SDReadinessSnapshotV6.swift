//
//  SDReadinessSnapshotV6.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDReadinessSnapshotV6 {
    @Attribute(.unique) var snapshotId: UUID
    var dayKey: String
    var computedAt: Date
    var score: Int
    var bandRaw: String
    var summary: String
    var componentsData: Data

    init(
        snapshotId: UUID = UUID(),
        dayKey: String,
        computedAt: Date,
        score: Int,
        bandRaw: String,
        summary: String,
        componentsData: Data
    ) {
        self.snapshotId = snapshotId
        self.dayKey = dayKey
        self.computedAt = computedAt
        self.score = score
        self.bandRaw = bandRaw
        self.summary = summary
        self.componentsData = componentsData
    }
}

struct ReadinessComponentRecord: Codable, Sendable {
    let kindRaw: String
    let score: Double
    let weight: Double
    let detail: String
    let isAvailable: Bool
}

extension SDReadinessSnapshotV6 {
    func toReadinessScore() -> ReadinessScore? {
        guard let band = ReadinessBand(rawValue: bandRaw) else { return nil }
        let records = (try? JSONDecoder().decode([ReadinessComponentRecord].self, from: componentsData)) ?? []
        let components = records.compactMap { record -> ReadinessComponent? in
            guard let kind = ReadinessComponentKind(rawValue: record.kindRaw) else { return nil }
            return ReadinessComponent(
                kind: kind,
                score: record.score,
                weight: record.weight,
                detail: record.detail,
                isAvailable: record.isAvailable
            )
        }
        return ReadinessScore(
            id: snapshotId,
            dayKey: dayKey,
            computedAt: computedAt,
            score: score,
            band: band,
            summary: summary,
            components: components
        )
    }

    static func from(score: ReadinessScore) -> SDReadinessSnapshotV6 {
        let records = score.components.map {
            ReadinessComponentRecord(
                kindRaw: $0.kind.rawValue,
                score: $0.score,
                weight: $0.weight,
                detail: $0.detail,
                isAvailable: $0.isAvailable
            )
        }
        let data = (try? JSONEncoder().encode(records)) ?? Data()
        return SDReadinessSnapshotV6(
            snapshotId: score.id,
            dayKey: score.dayKey,
            computedAt: score.computedAt,
            score: score.score,
            bandRaw: score.band.rawValue,
            summary: score.summary,
            componentsData: data
        )
    }
}
