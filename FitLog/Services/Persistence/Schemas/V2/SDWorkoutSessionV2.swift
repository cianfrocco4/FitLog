//
//  SDWorkoutSessionV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutSessionV2 {
    var sessionId: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var sessionNotes: String = ""
    /// JSON-encoded `Workout` snapshot (embedded at session start, contains exercise rows).
    var workoutSnapshotData: Data = Data()
    /// JSON-encoded `[UUID]` — active exercise IDs.
    var activeExerciseIdsData: Data = Data()
    /// JSON-encoded `[UUID]` — completed exercise IDs.
    var completedExerciseIdsData: Data = Data()
    /// JSON-encoded `WorkoutPlanRef?` — what the plan scheduled for this session.
    var planOriginData: Data?

    /// True when the session has no end time (still in progress).
    var isActive: Bool { endTime == nil }

    @Relationship(deleteRule: .cascade, inverse: \SDExerciseLogV2.session)
    var logs: [SDExerciseLogV2] = []

    @Relationship(deleteRule: .nullify)
    var workout: SDWorkoutV2?

    init() {}

    init(
        sessionId: UUID,
        startTime: Date,
        endTime: Date?,
        sessionNotes: String,
        workoutSnapshotData: Data,
        activeExerciseIdsData: Data,
        completedExerciseIdsData: Data,
        planOriginData: Data?
    ) {
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.sessionNotes = sessionNotes
        self.workoutSnapshotData = workoutSnapshotData
        self.activeExerciseIdsData = activeExerciseIdsData
        self.completedExerciseIdsData = completedExerciseIdsData
        self.planOriginData = planOriginData
    }

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

    static func from(_ s: WorkoutSession) -> SDWorkoutSessionV2 {
        let wData = versionedEncode(s.workout)
        let activeData = versionedEncode(s.activeExerciseIds)
        let completedData = versionedEncode(s.completedExerciseIds)
        let originData = s.sessionPlanOrigin.map { versionedEncode($0) }

        let sd = SDWorkoutSessionV2(
            sessionId: s.id,
            startTime: s.startTime,
            endTime: s.endTime,
            sessionNotes: s.sessionNotes,
            workoutSnapshotData: wData,
            activeExerciseIdsData: activeData,
            completedExerciseIdsData: completedData,
            planOriginData: originData
        )
        sd.logs = s.exerciseLogs.enumerated().map { idx, log in SDExerciseLogV2.from(log, orderIndex: idx) }
        return sd
    }
}
