//
//  SDDayOverrideV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDDayOverrideV3 {
    var dayKey: String = ""
    var intentRaw: String = "inherit"
    var planRefData: Data?

    var program: SDTrainingProgramV3?

    init() {}

    func toDomain() -> (key: String, value: ScheduleDayOverride) {
        let intent = ScheduleDayIntent(rawValue: intentRaw) ?? .inherit
        let planRef = planRefData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return (dayKey, ScheduleDayOverride(intent: intent, planRef: planRef))
    }
}
