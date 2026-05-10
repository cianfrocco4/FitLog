//
//  SDPersonalRecordV2.swift
//  FitLog
//
//  Pre-computed PR rows maintained incrementally on every logSet call.
//  Replaces the full-history scan in PersonalRecordDetector with O(1) lookups.
//

import Foundation
import SwiftData

@Model
final class SDPersonalRecordV2 {
    var prId: UUID = UUID()
    /// Exercise this PR belongs to.
    var exerciseId: UUID = UUID()
    var kindRaw: String = PRKind.maxWeight.rawValue
    var value: Double = 0
    var setId: UUID = UUID()
    var sessionId: UUID = UUID()
    var achievedAt: Date = Date()

    init() {}

    init(
        prId: UUID,
        exerciseId: UUID,
        kindRaw: String,
        value: Double,
        setId: UUID,
        sessionId: UUID,
        achievedAt: Date
    ) {
        self.prId = prId
        self.exerciseId = exerciseId
        self.kindRaw = kindRaw
        self.value = value
        self.setId = setId
        self.sessionId = sessionId
        self.achievedAt = achievedAt
    }

    var kind: PRKind { PRKind(rawValue: kindRaw) ?? .maxWeight }
}
