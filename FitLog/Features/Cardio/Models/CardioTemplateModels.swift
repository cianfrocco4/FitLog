//
//  CardioTemplateModels.swift
//  FitLog
//
//  Workout templates for the cardio builder (references seed catalog by stable index).
//

import Foundation

/// One row in a cardio workout template — resolved against `CardioExerciseSeed` at apply time.
struct CardioTemplateRowSpec: Equatable, Hashable, Sendable {
    /// Stable seed index from `CardioExerciseSeed.id(_:)`.
    var seedIndex: UInt16
    var prescription: CardioPrescription

    init(seedIndex: UInt16, prescription: CardioPrescription) {
        self.seedIndex = seedIndex
        self.prescription = prescription
    }
}

/// Library template applied in `CardioWorkoutBuilderView`.
struct CardioWorkoutTemplate: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let workoutKind: WorkoutKind
    let rows: [CardioTemplateRowSpec]

    init(
        id: String,
        name: String,
        subtitle: String,
        workoutKind: WorkoutKind = .cardio,
        rows: [CardioTemplateRowSpec]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.workoutKind = workoutKind
        self.rows = rows
    }
}
