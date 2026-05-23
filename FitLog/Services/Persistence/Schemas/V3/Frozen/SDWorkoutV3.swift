//
//  SDWorkoutV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDWorkoutV3 {
    var workoutId: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var templateSlotBindingsData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SDWorkoutExerciseRowV3.workout)
    var rows: [SDWorkoutExerciseRowV3] = []

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutSessionV3.workout)
    var sessions: [SDWorkoutSessionV3] = []

    @Relationship(deleteRule: .nullify, inverse: \SDProgramCycleEntryV3.referencedWorkout)
    var programCycleEntries: [SDProgramCycleEntryV3] = []

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
            templateSlotIdByWorkoutExerciseId: slotBindings,
            workoutKind: .strength
        )
        w.normalizeTemplateSlotBindingsAfterDecoding()
        return w
    }
}
