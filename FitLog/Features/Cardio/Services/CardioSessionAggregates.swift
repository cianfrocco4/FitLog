//
//  CardioSessionAggregates.swift
//  FitLog
//
//  Session-level cardio totals for insights, completion, and HealthKit export.
//

import Foundation

struct CardioSessionAggregates: Equatable, Sendable {
    var durationSeconds: Int
    var distanceMeters: Double
    var calories: Double
    var segmentCount: Int
    var dominantActivityKind: CardioActivityKind?

    static let empty = CardioSessionAggregates(
        durationSeconds: 0,
        distanceMeters: 0,
        calories: 0,
        segmentCount: 0,
        dominantActivityKind: nil
    )

    var hasCardio: Bool { segmentCount > 0 && durationSeconds > 0 }
}

enum CardioSessionAggregatesCalculator {
    static func aggregates(
        for session: WorkoutSession,
        exercises: [Exercise]
    ) -> CardioSessionAggregates {
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        var duration = 0
        var distance = 0.0
        var calories = 0.0
        var count = 0
        var activityDurations: [CardioActivityKind: Int] = [:]

        for log in session.exerciseLogs {
            let activity = log.workoutExercise.exerciseId.flatMap { byId[$0] }?.cardioMetadata?.activityKind
            for set in log.loggedSets where set.countsTowardCardioTotals {
                guard let m = set.cardioMetrics else { continue }
                count += 1
                if let sec = m.durationSec { duration += sec }
                if let mDist = m.distanceM { distance += mDist }
                if let cal = m.calories { calories += cal }
                if let sec = m.durationSec, sec > 0, let activity {
                    activityDurations[activity, default: 0] += sec
                }
            }
        }

        let dominant = activityDurations.max(by: { $0.value < $1.value })?.key
        return CardioSessionAggregates(
            durationSeconds: duration,
            distanceMeters: distance,
            calories: calories,
            segmentCount: count,
            dominantActivityKind: dominant
        )
    }

    /// Rough strength work time estimate for hybrid HealthKit activity selection.
    static func estimatedStrengthSeconds(in session: WorkoutSession) -> Int {
        let workingSets = session.exerciseLogs
            .flatMap(\.loggedSets)
            .filter { $0.countsTowardVolumeTotals }
            .count
        return workingSets * 180
    }
}

extension DataManager {
    /// True when at least one completed session includes cardio segments.
    func hasLoggedCardio(in sessions: [WorkoutSession]? = nil) -> Bool {
        let rows = sessions ?? completedSessions
        return rows.contains { session in
            session.isCompleted
                && CardioSessionAggregatesCalculator.aggregates(for: session, exercises: globalExercises).hasCardio
        }
    }

    /// True when the library includes a cardio or hybrid workout template.
    func hasCardioWorkoutInLibrary() -> Bool {
        userWorkouts.contains { $0.workoutKind == .cardio || $0.workoutKind == .hybrid }
    }
}
