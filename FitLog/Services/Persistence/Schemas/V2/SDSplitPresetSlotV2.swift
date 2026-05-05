//
//  SDSplitPresetSlotV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSplitPresetSlotV2 {
    var orderIndex: Int = 0
    var exerciseName: String = ""
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"

    var day: SDSplitPresetDayV2?

    init() {}

    init(orderIndex: Int, exerciseName: String, recommendedSets: Int, recommendedReps: String) {
        self.orderIndex = orderIndex
        self.exerciseName = exerciseName
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
    }
}
