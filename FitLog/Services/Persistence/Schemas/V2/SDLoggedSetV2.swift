//
//  SDLoggedSetV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDLoggedSetV2 {
    var setId: UUID = UUID()
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var restTime: Int = 90
    var timestamp: Date = Date()
    var setTypeRaw: String = "working"
    var rpe: Double?
    var cardioMetricsData: Data = Data()
    /// JSON-encoded `[String: String]` — per-set configuration k/v map (sparse, intentionally a blob).
    var configurationData: Data = Data()

    var log: SDExerciseLogV2?

    @Relationship(deleteRule: .cascade, inverse: \SDDropSegmentV2.parentSet)
    var dropSegments: [SDDropSegmentV2] = []

    init() {}

    init(
        setId: UUID,
        orderIndex: Int,
        weight: Double,
        reps: Int,
        restTime: Int,
        timestamp: Date,
        setTypeRaw: String,
        rpe: Double?,
        configurationData: Data,
        cardioMetricsData: Data = Data()
    ) {
        self.setId = setId
        self.orderIndex = orderIndex
        self.weight = weight
        self.reps = reps
        self.restTime = restTime
        self.timestamp = timestamp
        self.setTypeRaw = setTypeRaw
        self.rpe = rpe
        self.configurationData = configurationData
        self.cardioMetricsData = cardioMetricsData
    }

    func toDomain() -> LoggedSet {
        let setType = ExerciseSetType(rawValue: setTypeRaw) ?? .working
        let config = versionedDecode([String: String].self, from: configurationData) ?? [:]
        let drops = dropSegments.sorted { $0.orderIndex < $1.orderIndex }.map { $0.toDomain() }
        let cardio = versionedDecode(CardioMetrics.self, from: cardioMetricsData)
        return LoggedSet(
            id: setId,
            weight: weight,
            reps: reps,
            restTime: restTime,
            timestamp: timestamp,
            setType: setType,
            configuration: config,
            dropSegments: drops,
            rpe: rpe,
            cardioMetrics: cardio
        )
    }

    static func from(_ s: LoggedSet, orderIndex: Int) -> SDLoggedSetV2 {
        let configData = s.configuration.isEmpty ? Data() : versionedEncode(s.configuration)
        let cardioData = s.cardioMetrics.map { versionedEncode($0) } ?? Data()
        let sd = SDLoggedSetV2(
            setId: s.id,
            orderIndex: orderIndex,
            weight: s.weight,
            reps: s.reps,
            restTime: s.restTime,
            timestamp: s.timestamp,
            setTypeRaw: s.setType.rawValue,
            rpe: s.rpe,
            configurationData: configData,
            cardioMetricsData: cardioData
        )
        sd.dropSegments = s.dropSegments.enumerated().map { idx, seg in
            SDDropSegmentV2.from(seg, orderIndex: idx)
        }
        return sd
    }
}
