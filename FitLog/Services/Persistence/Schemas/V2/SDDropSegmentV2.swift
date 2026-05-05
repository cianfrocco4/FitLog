//
//  SDDropSegmentV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDDropSegmentV2 {
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    /// "drop" or "cluster" — defaults to drop for all existing rows.
    var kindRaw: String = "drop"

    var parentSet: SDLoggedSetV2?

    init() {}

    init(orderIndex: Int, weight: Double, reps: Int, kindRaw: String = "drop") {
        self.orderIndex = orderIndex
        self.weight = weight
        self.reps = reps
        self.kindRaw = kindRaw
    }

    func toDomain() -> DropSetSegment {
        DropSetSegment(weight: weight, reps: reps)
    }

    static func from(_ seg: DropSetSegment, orderIndex: Int) -> SDDropSegmentV2 {
        SDDropSegmentV2(orderIndex: orderIndex, weight: seg.weight, reps: seg.reps)
    }
}
