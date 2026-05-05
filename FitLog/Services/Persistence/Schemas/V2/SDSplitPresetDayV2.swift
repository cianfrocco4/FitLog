//
//  SDSplitPresetDayV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSplitPresetDayV2 {
    var orderIndex: Int = 0
    var dayName: String = ""

    var preset: SDSplitPresetV2?

    @Relationship(deleteRule: .cascade, inverse: \SDSplitPresetSlotV2.day)
    var slots: [SDSplitPresetSlotV2] = []

    init() {}

    init(orderIndex: Int, dayName: String) {
        self.orderIndex = orderIndex
        self.dayName = dayName
    }
}
