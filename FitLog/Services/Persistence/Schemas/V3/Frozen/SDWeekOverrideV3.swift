//
//  SDWeekOverrideV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWeekOverrideV3 {
    var weekKey: String = ""
    var weekdayOverridesData: Data = Data()

    var program: SDTrainingProgramV3?

    init() {}

    func toDomain() -> (key: String, value: ScheduleWeekOverride) {
        let overrides = versionedDecode([String: ScheduleDayOverride].self, from: weekdayOverridesData) ?? [:]
        return (weekKey, ScheduleWeekOverride(weekdayOverrides: overrides))
    }
}
