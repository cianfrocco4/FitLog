//
//  SDExerciseDisplayNameV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDExerciseDisplayNameV2 {
    var exerciseId: UUID = UUID()
    var customName: String = ""

    var exercise: SDExerciseV2?

    init() {}

    init(exerciseId: UUID, customName: String) {
        self.exerciseId = exerciseId
        self.customName = customName
    }
}
