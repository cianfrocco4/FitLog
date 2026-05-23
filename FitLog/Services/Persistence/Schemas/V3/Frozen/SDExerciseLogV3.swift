//
//  SDExerciseLogV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDExerciseLogV3 {
    var logId: UUID = UUID()
    var orderIndex: Int = 0
    var notes: String = ""
    var sessionRestOverrideSeconds: Int?
    var nameSnapshot: String = ""
    var slotLabelSnapshot: String = ""
    var exerciseIdSnapshot: UUID?
    var workoutExerciseData: Data = Data()

    var session: SDWorkoutSessionV3?

    var exercise: SDExerciseV3?

    @Relationship(deleteRule: .cascade, inverse: \SDLoggedSetV3.log)
    var sets: [SDLoggedSetV3] = []

    init() {}

    func toDomain() -> ExerciseLog? {
        guard let we = versionedDecode(WorkoutExercise.self, from: workoutExerciseData) else { return nil }
        let sortedSets = sets.sorted { $0.orderIndex < $1.orderIndex }
        let loggedSets = sortedSets.map { $0.toDomain() }
        return ExerciseLog(
            id: logId,
            workoutExercise: we,
            loggedSets: loggedSets,
            notes: notes,
            sessionRestOverrideSeconds: sessionRestOverrideSeconds
        )
    }
}
