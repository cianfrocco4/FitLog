//
//  SDWorkoutSessionV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutSessionV3 {
    var sessionId: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var sessionNotes: String = ""
    var workoutSnapshotData: Data = Data()
    var activeExerciseIdsData: Data = Data()
    var completedExerciseIdsData: Data = Data()
    var planOriginData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SDExerciseLogV3.session)
    var logs: [SDExerciseLogV3] = []

    var workout: SDWorkoutV3?

    init() {}

    func toDomain() -> WorkoutSession? {
        guard let workoutSnapshot = versionedDecode(Workout.self, from: workoutSnapshotData) else { return nil }
        let sortedLogs = logs.sorted { $0.orderIndex < $1.orderIndex }
        let exerciseLogs = sortedLogs.compactMap { $0.toDomain() }
        let activeIds = versionedDecode([UUID].self, from: activeExerciseIdsData) ?? []
        let completedIds = versionedDecode([UUID].self, from: completedExerciseIdsData) ?? []
        let origin = planOriginData.flatMap { versionedDecode(WorkoutPlanRef.self, from: $0) }
        return WorkoutSession(
            id: sessionId,
            workout: workoutSnapshot,
            startTime: startTime,
            endTime: endTime,
            exerciseLogs: exerciseLogs,
            activeExerciseIds: activeIds,
            completedExerciseIds: completedIds,
            sessionPlanOrigin: origin,
            sessionNotes: sessionNotes
        )
    }
}
