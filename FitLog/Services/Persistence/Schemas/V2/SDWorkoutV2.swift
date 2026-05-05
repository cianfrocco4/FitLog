//
//  SDWorkoutV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutV2 {
    var workoutId: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    /// Encoded `[UUID: UUID]` — workout exercise row id → slot blueprint id (preserved for plan-ref compat).
    var templateSlotBindingsData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SDWorkoutExerciseRowV2.workout)
    var rows: [SDWorkoutExerciseRowV2] = []

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutSessionV2.workout)
    var sessions: [SDWorkoutSessionV2] = []

    @Relationship(deleteRule: .nullify, inverse: \SDProgramCycleEntryV2.referencedWorkout)
    var programCycleEntries: [SDProgramCycleEntryV2] = []

    init() {}

    init(workoutId: UUID, name: String, sortOrder: Int) {
        self.workoutId = workoutId
        self.name = name
        self.sortOrder = sortOrder
    }

    func toDomain() -> Workout {
        let sortedRows = rows.sorted { $0.orderIndex < $1.orderIndex }
        let exercises = sortedRows.map { $0.toDomain() }
        let slotBindings: [UUID: UUID] = templateSlotBindingsData
            .flatMap { versionedDecode([UUID: UUID].self, from: $0) } ?? [:]
        var w = Workout(
            id: workoutId, name: name,
            exercises: exercises,
            templateSlotIdByWorkoutExerciseId: slotBindings
        )
        w.normalizeTemplateSlotBindingsAfterDecoding()
        return w
    }

    static func from(_ w: Workout, sortOrder: Int) -> SDWorkoutV2 {
        let sd = SDWorkoutV2(workoutId: w.id, name: w.name, sortOrder: sortOrder)
        sd.rows = w.exercises.enumerated().map { idx, we in
            SDWorkoutExerciseRowV2.from(we, orderIndex: idx)
        }
        if !w.templateSlotIdByWorkoutExerciseId.isEmpty {
            sd.templateSlotBindingsData = versionedEncode(w.templateSlotIdByWorkoutExerciseId)
        }
        return sd
    }
}
