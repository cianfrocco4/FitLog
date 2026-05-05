//
//  SDWeekOverrideV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWeekOverrideV2 {
    /// ISO week key, e.g. "2025-W12"
    var weekKey: String = ""
    /// JSON-encoded `[String: ScheduleDayOverride]` — weekday overrides map.
    var weekdayOverridesData: Data = Data()

    var program: SDTrainingProgramV2?

    init() {}

    init(weekKey: String, weekdayOverridesData: Data) {
        self.weekKey = weekKey
        self.weekdayOverridesData = weekdayOverridesData
    }

    func toDomain() -> (key: String, value: ScheduleWeekOverride) {
        let overrides = versionedDecode([String: ScheduleDayOverride].self, from: weekdayOverridesData) ?? [:]
        return (weekKey, ScheduleWeekOverride(weekdayOverrides: overrides))
    }

    static func from(key: String, override: ScheduleWeekOverride) -> SDWeekOverrideV2 {
        let data = versionedEncode(override.weekdayOverrides)
        return SDWeekOverrideV2(weekKey: key, weekdayOverridesData: data)
    }
}
