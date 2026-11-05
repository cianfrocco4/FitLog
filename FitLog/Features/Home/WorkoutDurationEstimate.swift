//
//  WorkoutDurationEstimate.swift
//  FitLog
//
//  Planned session length. Lifting stays on the per-exercise estimate users already
//  trust. Cardio adds the prescription length (or interval work plus rest) on top.
//

import Foundation

struct WorkoutDurationEstimate: Equatable {
    let liftingMinutes: Int
    let cardioMinutes: Int

    var totalMinutes: Int { liftingMinutes + cardioMinutes }

    /// Library and plan subtitle. Empty when the workout has no exercises to time.
    var summary: String {
        if liftingMinutes > 0 && cardioMinutes > 0 {
            return "~\(totalMinutes) min · \(liftingMinutes) lifting · \(cardioMinutes) cardio"
        }
        if cardioMinutes > 0 {
            return "~\(cardioMinutes) min cardio"
        }
        if liftingMinutes > 0 {
            return "~\(liftingMinutes) min"
        }
        return ""
    }

    static func make(workout: Workout, library: [Exercise]) -> WorkoutDurationEstimate {
        make(exercises: workout.exercises, library: library)
    }

    static func make(exercises: [WorkoutExercise], library: [Exercise]) -> WorkoutDurationEstimate {
        var liftingCount = 0
        var cardioSeconds = 0
        for exercise in exercises {
            if CardioWorkoutExerciseHelpers.isCardioLoggingRow(exercise, exercises: library) {
                cardioSeconds += Self.cardioSeconds(for: exercise)
            } else {
                liftingCount += 1
            }
        }
        let includesCardio = cardioSeconds > 0
        return WorkoutDurationEstimate(
            liftingMinutes: liftingMinutes(strengthExerciseCount: liftingCount, includesCardio: includesCardio),
            cardioMinutes: minutes(fromSeconds: cardioSeconds)
        )
    }

    /// Same 8 minutes per lifting exercise as the home list, with the 15-minute floor
    /// only when the workout has no cardio to add.
    static func liftingMinutes(strengthExerciseCount: Int, includesCardio: Bool) -> Int {
        guard strengthExerciseCount > 0 else { return 0 }
        if includesCardio { return strengthExerciseCount * 8 }
        return HomeWorkoutFormatting.estimatedDurationMinutes(exerciseCount: strengthExerciseCount)
    }

    /// Prescription duration, otherwise interval work and rest, otherwise distance at the target pace.
    /// Cardio with no timing info still counts as 20 minutes so it is not dropped from the total.
    static func cardioSeconds(for exercise: WorkoutExercise) -> Int {
        let fallback = 20 * 60
        guard let prescription = exercise.effectiveCardioPrescription else { return fallback }
        if let seconds = prescription.targetDurationSec, seconds > 0 { return seconds }
        let interval = prescription.intervals.reduce(0) { partial, spec in
            let work = spec.workDurationSec ?? 0
            let rest = spec.restDurationSec ?? 0
            guard work + rest > 0 else { return partial }
            return partial + (work + rest) * max(1, spec.repeatCount)
        }
        if interval > 0 { return interval }
        if let meters = prescription.targetDistanceM,
           let pace = prescription.targetPaceSecPerKm,
           meters > 0,
           pace > 0 {
            return max(60, Int((meters / 1000.0) * Double(pace).rounded()))
        }
        return fallback
    }

    static func minutes(fromSeconds seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return max(1, Int((Double(seconds) / 60.0).rounded()))
    }
}
