//
//  SDExerciseLogV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDExerciseLogV2 {
    var logId: UUID = UUID()
    var orderIndex: Int = 0
    var notes: String = ""
    var sessionRestOverrideSeconds: Int?
    /// Name of the exercise at time of logging (snapshot for history).
    var nameSnapshot: String = ""
    /// Slot label when this log came from a flexible slot.
    var slotLabelSnapshot: String = ""
    /// Exercise ID at time of logging for incremental PR queries.
    var exerciseIdSnapshot: UUID?
    /// Full JSON of the `WorkoutExercise` — preserves slot resolution, config, etc. for domain reconstruction.
    var workoutExerciseData: Data = Data()

    var session: SDWorkoutSessionV2?

    var exercise: SDExerciseV2?

    @Relationship(deleteRule: .cascade, inverse: \SDLoggedSetV2.log)
    var sets: [SDLoggedSetV2] = []

    init() {}

    init(
        logId: UUID,
        orderIndex: Int,
        notes: String,
        sessionRestOverrideSeconds: Int?,
        nameSnapshot: String,
        slotLabelSnapshot: String,
        exerciseIdSnapshot: UUID?,
        workoutExerciseData: Data
    ) {
        self.logId = logId
        self.orderIndex = orderIndex
        self.notes = notes
        self.sessionRestOverrideSeconds = sessionRestOverrideSeconds
        self.nameSnapshot = nameSnapshot
        self.slotLabelSnapshot = slotLabelSnapshot
        self.exerciseIdSnapshot = exerciseIdSnapshot
        self.workoutExerciseData = workoutExerciseData
    }

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

    static func from(_ log: ExerciseLog, orderIndex: Int) -> SDExerciseLogV2 {
        let weData = versionedEncode(log.workoutExercise)
        let nameSnap: String
        let slotLabel: String
        let exerciseId: UUID?

        switch log.workoutExercise.resolution {
        case .concrete(let snap):
            nameSnap = snap.nameAtTimeOfLog
            slotLabel = ""
            exerciseId = snap.exerciseId
        case .flexible(let b):
            nameSnap = b.label
            slotLabel = b.label
            exerciseId = b.defaultExerciseId
        }

        let sd = SDExerciseLogV2(
            logId: log.id,
            orderIndex: orderIndex,
            notes: log.notes,
            sessionRestOverrideSeconds: log.sessionRestOverrideSeconds,
            nameSnapshot: nameSnap,
            slotLabelSnapshot: slotLabel,
            exerciseIdSnapshot: exerciseId,
            workoutExerciseData: weData
        )
        sd.sets = log.loggedSets.enumerated().map { idx, s in SDLoggedSetV2.from(s, orderIndex: idx) }
        return sd
    }
}
