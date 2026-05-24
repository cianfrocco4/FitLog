//
//  CardioProgramTemplates.swift
//  FitLog
//
//  Endurance-focused rotation templates for dynamic programs.
//

import Foundation

enum CardioProgramTemplates {
    /// Short post-strength finisher (10 min Zone 2).
    static func finisherSlot(library: [Exercise]) -> SplitBuilderEditableSlot {
        let cardioExercises = library.filter { $0.modality == .cardio || $0.modality == .hybrid }
        let run = pickExercise(named: "Treadmill Run", kind: .run, from: cardioExercises)
            ?? pickExercise(named: "Outdoor Run", kind: .run, from: cardioExercises)
        return SplitBuilderEditableSlot(
            label: "Cardio finisher",
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 1,
            reps: "steady",
            suggestedExerciseName: run?.name,
            suggestedExerciseOverrideId: run?.id,
            modality: .cardio,
            cardioPrescription: CardioPrescription(
                kind: .steadyState,
                targetDurationSec: 10 * 60,
                targetZone: .zone2,
                notes: "Optional cooldown after lifting."
            )
        )
    }

    /// One cardio-only rotation day (cycles through zone 2, intervals, cycling, rowing).
    static func dedicatedCardioDay(library: [Exercise], index: Int) -> BlockWeeklyTemplate {
        let cardioExercises = library.filter { $0.modality == .cardio || $0.modality == .hybrid }
        let run = pickExercise(named: "Treadmill Run", kind: .run, from: cardioExercises)
        let bike = pickExercise(named: "Indoor Cycling", kind: .cycle, from: cardioExercises)
            ?? pickExercise(named: "Stationary Bike", kind: .cycle, from: cardioExercises)
        let row = pickExercise(named: "Rowing Machine Steady", kind: .row, from: cardioExercises)
            ?? pickExercise(named: "Rowing Machine", kind: .row, from: cardioExercises)
        let zone2 = pickExercise(named: "Outdoor Run", kind: .run, from: cardioExercises)

        let dayBlueprints: [(String, String, CardioPrescription, Exercise?)] = [
            (
                "Zone 2",
                "Aerobic base",
                CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 45 * 60,
                    targetZone: .zone2
                ),
                zone2 ?? run
            ),
            (
                "Intervals",
                "VO₂ / tempo",
                CardioPrescription(
                    kind: .intervals,
                    intervals: [
                        CardioIntervalSpec(
                            workDurationSec: 180,
                            restDurationSec: 90,
                            targetZone: .zone4,
                            repeatCount: 6
                        )
                    ]
                ),
                run
            ),
            (
                "Cycling",
                "Low-impact endurance",
                CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 40 * 60,
                    targetZone: .zone2
                ),
                bike
            ),
            (
                "Rowing",
                "Full-body conditioning",
                CardioPrescription(
                    kind: .steadyState,
                    targetDistanceM: 5000,
                    targetZone: .zone3
                ),
                row
            )
        ]

        let blueprint = dayBlueprints[index % dayBlueprints.count]
        let slot = SplitBuilderEditableSlot(
            label: blueprint.0,
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 1,
            reps: "—",
            suggestedExerciseName: blueprint.3?.name,
            suggestedExerciseOverrideId: blueprint.3?.id,
            modality: .cardio,
            cardioPrescription: blueprint.2
        )
        return BlockWeeklyTemplate(
            dayName: blueprint.0,
            focus: blueprint.1,
            slots: [slot],
            dayNotes: "Cardio-focused session from your program."
        )
    }

    /// Builds cardio-focused `BlockWeeklyTemplate` rotation days for endurance blocks.
    static func enduranceWeeklyTemplates(
        sessionsPerWeek: Int,
        library: [Exercise]
    ) -> [BlockWeeklyTemplate] {
        let count = min(max(1, sessionsPerWeek), 7)
        return (0 ..< count).map { dedicatedCardioDay(library: library, index: $0) }
    }

    /// Default cardio slot for manual program builder (30 min Zone 2).
    static func defaultCardioSlot(library: [Exercise], label: String = "Cardio") -> SplitBuilderEditableSlot {
        var slot = finisherSlot(library: library)
        slot.label = label
        slot.cardioPrescription = CardioPrescription(
            kind: .steadyState,
            targetDurationSec: 30 * 60,
            targetZone: .zone2
        )
        return slot
    }

    private static func pickExercise(
        named preferred: String,
        kind: CardioActivityKind,
        from exercises: [Exercise]
    ) -> Exercise? {
        if let exact = exercises.first(where: { $0.name == preferred }) { return exact }
        return exercises.first { $0.cardioMetadata?.activityKind == kind }
            ?? exercises.first
    }
}
