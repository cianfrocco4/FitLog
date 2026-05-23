//
//  SDDropSegmentV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDDropSegmentV3 {
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var kindRaw: String = "drop"

    var parentSet: SDLoggedSetV3?

    init() {}

    func toDomain() -> DropSetSegment {
        DropSetSegment(weight: weight, reps: reps)
    }
}
