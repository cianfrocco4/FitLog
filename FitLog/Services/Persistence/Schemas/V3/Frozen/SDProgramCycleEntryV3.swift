//
//  SDProgramCycleEntryV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDProgramCycleEntryV3 {
    var orderIndex: Int = 0
    var workoutId: UUID = UUID()

    var program: SDTrainingProgramV2?

    var referencedWorkout: SDWorkoutV3?

    init() {}

    init(orderIndex: Int, workoutId: UUID) {
        self.orderIndex = orderIndex
        self.workoutId = workoutId
    }

    func toPlanRef() -> WorkoutPlanRef {
        .workout(workoutId)
    }
}
