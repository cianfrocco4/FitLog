//
//  CardioPeriodization.swift
//  FitLog
//
//  Scales cardio prescriptions from block volume multiplier and deload flags.
//

import Foundation

enum CardioPeriodization {
    /// Applies block `volumeMultiplier` to duration/distance targets; deload blocks use −30% duration.
    static func scaledPrescription(
        _ prescription: CardioPrescription,
        blockContext: BlockContext?
    ) -> CardioPrescription {
        guard let ctx = blockContext else { return prescription }
        let scale = effectiveScale(blockContext: ctx)
        guard scale != 1.0 else { return prescription }

        var rx = prescription
        if let sec = rx.targetDurationSec, sec > 0 {
            rx.targetDurationSec = max(60, Int((Double(sec) * scale).rounded()))
        }
        if let meters = rx.targetDistanceM, meters > 0 {
            rx.targetDistanceM = max(100, meters * scale)
        }
        rx.intervals = rx.intervals.map { scaledInterval($0, scale: scale) }
        return rx
    }

    /// Applies progression scaling to every cardio prescription on a workout copy.
    static func applyProgression(to workout: Workout, blockContext: BlockContext?) -> Workout {
        guard blockContext != nil else { return workout }
        var copy = workout
        copy.exercises = workout.exercises.map { row in
            var we = row
            if let base = we.effectiveCardioPrescription {
                we.cardioPrescription = scaledPrescription(base, blockContext: blockContext)
            } else if case .flexible(var blueprint) = we.resolution,
                      let base = blueprint.cardioPrescription {
                blueprint.cardioPrescription = scaledPrescription(base, blockContext: blockContext)
                we.resolution = .flexible(blueprint)
            }
            return we
        }
        return copy
    }

    private static func effectiveScale(blockContext: BlockContext) -> Double {
        if blockContext.isDeloadBlock { return 0.7 }
        return max(0.5, min(1.35, blockContext.volumeMultiplier))
    }

    private static func scaledInterval(_ spec: CardioIntervalSpec, scale: Double) -> CardioIntervalSpec {
        var s = spec
        if let work = s.workDurationSec, work > 0 {
            s.workDurationSec = max(10, Int((Double(work) * scale).rounded()))
        }
        if let dist = s.workDistanceM, dist > 0 {
            s.workDistanceM = max(50, dist * scale)
        }
        if let rest = s.restDurationSec, rest > 0 {
            s.restDurationSec = max(5, Int((Double(rest) * scale).rounded()))
        }
        return s
    }
}
