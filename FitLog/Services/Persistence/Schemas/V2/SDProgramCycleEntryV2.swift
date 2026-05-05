//
//  SDProgramCycleEntryV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDProgramCycleEntryV2 {
    var orderIndex: Int = 0
    /// UUID of the referenced library workout.
    var workoutId: UUID = UUID()

    var program: SDTrainingProgramV2?

    @Relationship(deleteRule: .nullify)
    var referencedWorkout: SDWorkoutV2?

    init() {}

    init(orderIndex: Int, workoutId: UUID) {
        self.orderIndex = orderIndex
        self.workoutId = workoutId
    }

    func toPlanRef() -> WorkoutPlanRef {
        .workout(workoutId)
    }
}
