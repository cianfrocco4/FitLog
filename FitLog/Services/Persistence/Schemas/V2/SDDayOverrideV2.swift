//
//  SDDayOverrideV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDDayOverrideV2 {
    /// "yyyy-MM-dd"
    var dayKey: String = ""
    var intentRaw: String = "inherit"
    /// JSON-encoded `WorkoutPlanRef` (only when intent == "workout").
    var planRefData: Data?

    var program: SDTrainingProgramV2?

    init() {}

    init(dayKey: String, intentRaw: String, planRefData: Data?) {
        self.dayKey = dayKey
        self.intentRaw = intentRaw
        self.planRefData = planRefData
    }

    func toDomain() -> (key: String, value: ScheduleDayOverride) {
        let intent = ScheduleDayIntent(rawValue: intentRaw) ?? .inherit
        let planRef = planRefData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return (dayKey, ScheduleDayOverride(intent: intent, planRef: planRef))
    }

    static func from(key: String, override: ScheduleDayOverride) -> SDDayOverrideV2 {
        let refData = override.planRef.map { versionedEncode($0) }
        return SDDayOverrideV2(dayKey: key, intentRaw: override.intent.rawValue, planRefData: refData)
    }
}
