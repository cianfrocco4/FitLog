//
//  SDFrozenPlanDayV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDFrozenPlanDayV2 {
    /// "yyyy-MM-dd"
    var dayKey: String = ""
    /// "rest", "unscheduled", or "workout"
    var kindRaw: String = "unscheduled"
    /// JSON-encoded `WorkoutPlanRef` (only when kind == "workout").
    var workoutRefData: Data?

    var program: SDTrainingProgramV2?

    init() {}

    init(dayKey: String, kindRaw: String, workoutRefData: Data?) {
        self.dayKey = dayKey
        self.kindRaw = kindRaw
        self.workoutRefData = workoutRefData
    }

    func toDomain() -> (key: String, value: FrozenPlanDay) {
        let kind = FrozenPlanDay.Kind(rawValue: kindRaw) ?? .unscheduled
        let ref = workoutRefData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return (dayKey, FrozenPlanDay(kind: kind, workoutRef: ref))
    }

    static func from(key: String, day: FrozenPlanDay) -> SDFrozenPlanDayV2 {
        let kindRaw = day.kind.rawValue
        let refData = day.workoutRef.map { versionedEncode($0) }
        return SDFrozenPlanDayV2(dayKey: key, kindRaw: kindRaw, workoutRefData: refData)
    }
}
