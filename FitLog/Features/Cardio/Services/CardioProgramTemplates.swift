//
//  CardioProgramTemplates.swift
//  FitLog
//
//  Endurance-focused rotation templates for dynamic programs.
//

import Foundation

enum CardioProgramTemplates {
    /// Short post-strength finisher.
    static func finisherSlot(
        library: [Exercise],
        configuration: CardioProgramConfiguration = CardioProgramConfiguration(preference: .postWorkout)
    ) -> SplitBuilderEditableSlot {
        let cardioExercises = library.filter { $0.modality == .cardio || $0.modality == .hybrid }
        let run = pickExercise(named: "Treadmill Run", kind: .run, from: cardioExercises)
            ?? pickExercise(named: "Outdoor Run", kind: .run, from: cardioExercises)
        let durationSec = configuration.finisherDurationMinutes * 60
        let zone = configuration.goal == .activeRecovery ? CardioIntensityZone.zone1 : configuration.finisherZone
        return SplitBuilderEditableSlot(
            label: finisherLabel(for: configuration),
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 1,
            reps: configuration.goal == .fatLoss ? "intervals" : "steady",
            suggestedExerciseName: run?.name,
            suggestedExerciseOverrideId: run?.id,
            modality: .cardio,
            cardioPrescription: finisherPrescription(configuration: configuration, durationSec: durationSec, zone: zone)
        )
    }

    /// One cardio-only rotation day (goal-driven blueprint rotation).
    static func dedicatedCardioDay(
        library: [Exercise],
        index: Int,
        configuration: CardioProgramConfiguration = CardioProgramConfiguration(preference: .dedicatedDays)
    ) -> BlockWeeklyTemplate {
        let blueprints = dedicatedDayBlueprints(for: configuration.goal, library: library)
        let blueprint = blueprints[index % blueprints.count]
        let slot = SplitBuilderEditableSlot(
            label: blueprint.label,
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 1,
            reps: blueprint.repsToken,
            suggestedExerciseName: blueprint.exercise?.name,
            suggestedExerciseOverrideId: blueprint.exercise?.id,
            modality: .cardio,
            cardioPrescription: blueprint.prescription
        )
        return BlockWeeklyTemplate(
            dayName: blueprint.dayName,
            focus: blueprint.focus,
            slots: [slot],
            dayNotes: blueprint.dayNotes
        )
    }

    /// Builds cardio-focused `BlockWeeklyTemplate` rotation days for endurance blocks.
    static func enduranceWeeklyTemplates(
        sessionsPerWeek: Int,
        library: [Exercise],
        configuration: CardioProgramConfiguration = CardioProgramConfiguration(
            goal: .enduranceBuilding,
            preference: .dedicatedDays
        )
    ) -> [BlockWeeklyTemplate] {
        let count = min(max(1, sessionsPerWeek), 7)
        return (0 ..< count).map { dedicatedCardioDay(library: library, index: $0, configuration: configuration) }
    }

    /// Default cardio slot for manual program builder.
    static func defaultCardioSlot(
        library: [Exercise],
        label: String = "Cardio",
        configuration: CardioProgramConfiguration = CardioProgramConfiguration(preference: .postWorkout)
    ) -> SplitBuilderEditableSlot {
        var slot = finisherSlot(library: library, configuration: configuration)
        slot.label = label
        slot.cardioPrescription = CardioPrescription(
            kind: .steadyState,
            targetDurationSec: max(5, configuration.finisherDurationMinutes) * 60,
            targetZone: configuration.finisherZone
        )
        return slot
    }

    // MARK: - Blueprints

    private struct DedicatedDayBlueprint {
        let dayName: String
        let focus: String
        let label: String
        let repsToken: String
        let prescription: CardioPrescription
        let exercise: Exercise?
        let dayNotes: String
    }

    private static func dedicatedDayBlueprints(
        for goal: CardioProgramGoal,
        library: [Exercise]
    ) -> [DedicatedDayBlueprint] {
        let cardioExercises = library.filter { $0.modality == .cardio || $0.modality == .hybrid }
        let run = pickExercise(named: "Treadmill Run", kind: .run, from: cardioExercises)
        let outdoor = pickExercise(named: "Outdoor Run", kind: .run, from: cardioExercises)
        let bike = pickExercise(named: "Indoor Cycling", kind: .cycle, from: cardioExercises)
            ?? pickExercise(named: "Stationary Bike", kind: .cycle, from: cardioExercises)
        let row = pickExercise(named: "Rowing Machine Steady", kind: .row, from: cardioExercises)
            ?? pickExercise(named: "Rowing Machine", kind: .row, from: cardioExercises)

        switch goal {
        case .generalHealth:
            return [
                blueprint(
                    dayName: "Zone 2",
                    focus: "Easy aerobic base",
                    label: "Easy cardio",
                    exercise: outdoor ?? run,
                    prescription: steady(durationMin: 25, zone: .zone2)
                ),
                blueprint(
                    dayName: "Walk / bike",
                    focus: "Low impact",
                    label: "Light conditioning",
                    exercise: bike,
                    prescription: steady(durationMin: 30, zone: .zone2)
                ),
            ]
        case .fatLoss:
            return [
                blueprint(
                    dayName: "HIIT",
                    focus: "Intervals",
                    label: "HIIT intervals",
                    exercise: run,
                    prescription: tabataIntervals(),
                    repsToken: "intervals"
                ),
                blueprint(
                    dayName: "Tempo",
                    focus: "Steady hard effort",
                    label: "Tempo block",
                    exercise: run ?? bike,
                    prescription: steady(durationMin: 25, zone: .zone3),
                    repsToken: "steady"
                ),
                blueprint(
                    dayName: "EMOM",
                    focus: "Conditioning",
                    label: "EMOM rounds",
                    exercise: row ?? run,
                    prescription: emomPrescription(),
                    repsToken: "circuit"
                ),
                blueprint(
                    dayName: "Finisher walk",
                    focus: "Recovery pace",
                    label: "Incline walk",
                    exercise: outdoor ?? run,
                    prescription: steady(durationMin: 20, zone: .zone2)
                ),
            ]
        case .enduranceBuilding:
            return [
                blueprint(
                    dayName: "Long Zone 2",
                    focus: "Aerobic base",
                    label: "Long steady",
                    exercise: outdoor ?? run,
                    prescription: steady(durationMin: 45, zone: .zone2)
                ),
                blueprint(
                    dayName: "Tempo run",
                    focus: "Threshold",
                    label: "Tempo",
                    exercise: run ?? outdoor,
                    prescription: steady(durationMin: 35, zone: .zone3)
                ),
                blueprint(
                    dayName: "Cycling",
                    focus: "Low-impact endurance",
                    label: "Endurance ride",
                    exercise: bike,
                    prescription: steady(durationMin: 40, zone: .zone2)
                ),
                blueprint(
                    dayName: "Rowing",
                    focus: "Full-body conditioning",
                    label: "Steady row",
                    exercise: row,
                    prescription: steady(distanceM: 5000, zone: .zone3)
                ),
            ]
        case .racePrep:
            return [
                blueprint(
                    dayName: "Intervals",
                    focus: "VO₂ / speed",
                    label: "Track intervals",
                    exercise: run,
                    prescription: pyramidIntervals(),
                    repsToken: "intervals"
                ),
                blueprint(
                    dayName: "Tempo",
                    focus: "Race pace",
                    label: "Tempo run",
                    exercise: run ?? outdoor,
                    prescription: steady(durationMin: 40, zone: .zone4)
                ),
                blueprint(
                    dayName: "Fartlek",
                    focus: "Unstructured speed",
                    label: "Fartlek",
                    exercise: outdoor ?? run,
                    prescription: fartlekPrescription(),
                    repsToken: "intervals"
                ),
                blueprint(
                    dayName: "Long run",
                    focus: "Endurance",
                    label: "Long steady",
                    exercise: outdoor ?? run,
                    prescription: steady(durationMin: 50, zone: .zone2)
                ),
            ]
        case .activeRecovery:
            return [
                blueprint(
                    dayName: "Easy walk",
                    focus: "Recovery",
                    label: "Walk",
                    exercise: pickExercise(named: "Outdoor Walk", kind: .walk, from: cardioExercises) ?? outdoor,
                    prescription: steady(durationMin: 20, zone: .zone1)
                ),
                blueprint(
                    dayName: "Light bike",
                    focus: "Flush",
                    label: "Easy spin",
                    exercise: bike,
                    prescription: steady(durationMin: 20, zone: .zone1)
                ),
            ]
        }
    }

    private static func blueprint(
        dayName: String,
        focus: String,
        label: String,
        exercise: Exercise?,
        prescription: CardioPrescription,
        repsToken: String = "steady",
        dayNotes: String = "Cardio-focused session from your program."
    ) -> DedicatedDayBlueprint {
        DedicatedDayBlueprint(
            dayName: dayName,
            focus: focus,
            label: label,
            repsToken: repsToken,
            prescription: prescription,
            exercise: exercise,
            dayNotes: dayNotes
        )
    }

    private static func finisherLabel(for configuration: CardioProgramConfiguration) -> String {
        switch configuration.goal {
        case .fatLoss: return "Conditioning finisher"
        case .activeRecovery: return "Recovery walk"
        default: return "Cardio finisher"
        }
    }

    private static func finisherPrescription(
        configuration: CardioProgramConfiguration,
        durationSec: Int,
        zone: CardioIntensityZone
    ) -> CardioPrescription {
        if configuration.goal == .fatLoss {
            return CardioPrescription(
                kind: .intervals,
                intervals: [
                    CardioIntervalSpec(
                        workDurationSec: 30,
                        restDurationSec: 30,
                        targetZone: .zone4,
                        repeatCount: max(4, durationSec / 60)
                    )
                ],
                notes: "Optional post-lifting finisher."
            )
        }
        return CardioPrescription(
            kind: .steadyState,
            targetDurationSec: durationSec,
            targetZone: zone,
            notes: "Optional cooldown after lifting."
        )
    }

    private static func steady(
        durationMin: Int? = nil,
        distanceM: Double? = nil,
        zone: CardioIntensityZone
    ) -> CardioPrescription {
        CardioPrescription(
            kind: .steadyState,
            targetDurationSec: durationMin.map { $0 * 60 },
            targetDistanceM: distanceM,
            targetZone: zone
        )
    }

    private static func tabataIntervals() -> CardioPrescription {
        CardioPrescription(
            kind: .intervals,
            intervals: [
                CardioIntervalSpec(workDurationSec: 20, restDurationSec: 10, targetZone: .zone5, repeatCount: 8)
            ],
            notes: "Tabata-style 20s on / 10s off."
        )
    }

    private static func pyramidIntervals() -> CardioPrescription {
        CardioPrescription(
            kind: .intervals,
            intervals: [
                CardioIntervalSpec(workDurationSec: 60, restDurationSec: 60, targetZone: .zone4, repeatCount: 4),
                CardioIntervalSpec(workDurationSec: 120, restDurationSec: 90, targetZone: .zone4, repeatCount: 3),
                CardioIntervalSpec(workDurationSec: 180, restDurationSec: 120, targetZone: .zone4, repeatCount: 2),
            ],
            notes: "Pyramid: shorter reps first, then longer efforts."
        )
    }

    private static func fartlekPrescription() -> CardioPrescription {
        CardioPrescription(
            kind: .intervals,
            targetDurationSec: 35 * 60,
            targetZone: .zone3,
            intervals: [
                CardioIntervalSpec(workDurationSec: 120, restDurationSec: 120, targetZone: .zone4, repeatCount: 6)
            ],
            notes: "Mix easy running with 2-minute surges."
        )
    }

    private static func emomPrescription() -> CardioPrescription {
        CardioPrescription(
            kind: .circuit,
            targetDurationSec: 16 * 60,
            targetZone: .zone4,
            intervals: [
                CardioIntervalSpec(workDurationSec: 45, restDurationSec: 15, targetZone: .zone4, repeatCount: 16)
            ],
            notes: "Every minute on the minute — work 45s, rest 15s."
        )
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
