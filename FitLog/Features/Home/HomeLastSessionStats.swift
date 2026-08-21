//
//  HomeLastSessionStats.swift
//  FitLog
//
//  Last-session duration for Home library rows (cardio minutes without opening History).
//

import Foundation

enum HomeLastSessionStats {
    /// Prefer logged cardio metrics; fall back to wall-clock for cardio/hybrid sessions.
    static func durationSeconds(from session: WorkoutSession, exercises: [Exercise]) -> Int? {
        guard let end = session.endTime else { return nil }
        let cardio = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: exercises)
        if cardio.hasCardio {
            return cardio.durationSeconds
        }
        let kind = session.workout.workoutKind
        guard kind == .cardio || kind == .hybrid else { return nil }
        let wall = Int(end.timeIntervalSince(session.startTime))
        return wall >= 30 ? wall : nil
    }
}
