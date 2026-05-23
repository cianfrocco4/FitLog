//
//  SDLoggedSetV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDLoggedSetV3 {
    var setId: UUID = UUID()
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var restTime: Int = 90
    var timestamp: Date = Date()
    var setTypeRaw: String = "working"
    var rpe: Double?
    var configurationData: Data = Data()

    var log: SDExerciseLogV3?

    @Relationship(deleteRule: .cascade, inverse: \SDDropSegmentV3.parentSet)
    var dropSegments: [SDDropSegmentV3] = []

    init() {}

    func toDomain() -> LoggedSet {
        let setType = ExerciseSetType(rawValue: setTypeRaw) ?? .working
        let config = versionedDecode([String: String].self, from: configurationData) ?? [:]
        let drops = dropSegments.sorted { $0.orderIndex < $1.orderIndex }.map { $0.toDomain() }
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
            cardioMetrics: nil
        )
    }
}
