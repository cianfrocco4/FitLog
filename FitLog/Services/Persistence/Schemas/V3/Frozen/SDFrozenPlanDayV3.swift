//
//  SDFrozenPlanDayV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDFrozenPlanDayV3 {
    var dayKey: String = ""
    var kindRaw: String = "unscheduled"
    var workoutRefData: Data?

    var program: SDTrainingProgramV3?

    init() {}

    func toDomain() -> (key: String, value: FrozenPlanDay) {
        let kind = FrozenPlanDay.Kind(rawValue: kindRaw) ?? .unscheduled
        let ref = workoutRefData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return (dayKey, FrozenPlanDay(kind: kind, workoutRef: ref))
    }
}
