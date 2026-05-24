//
//  CardioHealthKitMapping.swift
//  FitLog
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum CardioHealthKitMapping {
#if canImport(HealthKit)
    static func workoutActivityType(
        for session: WorkoutSession,
        exercises: [Exercise]
    ) -> HKWorkoutActivityType {
        let agg = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: exercises)
        let strengthEst = CardioSessionAggregatesCalculator.estimatedStrengthSeconds(in: session)
        let hasStrength = session.exerciseLogs.flatMap(\.loggedSets).contains { $0.countsTowardVolumeTotals }
        let hasCardio = agg.hasCardio

        if hasCardio && hasStrength {
            if agg.durationSeconds >= strengthEst { return activityType(for: agg.dominantActivityKind) }
            return .crossTraining
        }
        if hasCardio {
            return activityType(for: agg.dominantActivityKind)
        }
        return .traditionalStrengthTraining
    }

    static func activityType(for kind: CardioActivityKind?) -> HKWorkoutActivityType {
        switch kind {
        case .run: return .running
        case .walk: return .walking
        case .cycle: return .cycling
        case .row: return .rowing
        case .swim: return .swimming
        case .elliptical: return .elliptical
        case .stairClimber: return .stairClimbing
        case .jumpRope, .hiit: return .highIntensityIntervalTraining
        case .generic, .none: return .mixedCardio
        }
    }

    static func isIndoorWorkout(session: WorkoutSession, exercises: [Exercise]) -> Bool {
        let agg = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: exercises)
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        var sawIndoor = false
        var sawOutdoor = false
        for log in session.exerciseLogs {
            guard log.loggedSets.contains(where: { $0.countsTowardCardioTotals }),
                  let id = log.workoutExercise.exerciseId,
                  let equipment = byId[id]?.cardioMetadata?.equipment
            else { continue }
            switch equipment {
            case .treadmill, .bike, .rower, .machine, .pool:
                sawIndoor = true
            case .outdoor:
                sawOutdoor = true
            case .none:
                break
            }
        }
        if sawIndoor && !sawOutdoor { return true }
        if sawOutdoor && !sawIndoor { return false }
        if agg.hasCardio { return false }
        return false
    }

    static func distanceQuantityTypeIdentifier(for kind: CardioActivityKind?) -> HKQuantityTypeIdentifier {
        switch kind {
        case .cycle: return .distanceCycling
        case .swim: return .distanceSwimming
        case .row: return .distanceRowing
        default: return .distanceWalkingRunning
        }
    }

    static func distanceQuantityType(for kind: CardioActivityKind?) -> HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: distanceQuantityTypeIdentifier(for: kind))
    }
#endif
}
