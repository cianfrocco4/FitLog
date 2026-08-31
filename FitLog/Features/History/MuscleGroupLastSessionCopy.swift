//
//  MuscleGroupLastSessionCopy.swift
//  FitLog
//
//  Last working set / last workout for History Explore (by muscle) and muscle detail.
//  Does not unlock Premium charts or change the 14-day History cap.
//

import Foundation

enum MuscleGroupLastSessionCopy {
    /// Latest completed session that logged this muscle group (range-limited when `sessions` is).
    static func latest(
        muscleGroupName: String,
        in sessions: [WorkoutSession],
        resolve: (ExerciseSnapshot) -> Exercise?
    ) -> (session: WorkoutSession, logs: [ExerciseLog])? {
        sessions
            .compactMap { session -> (WorkoutSession, [ExerciseLog])? in
                guard session.isCompleted else { return nil }
                let logs = session.exerciseLogs.filter { log in
                    matchesMuscle(log: log, muscleGroupName: muscleGroupName, resolve: resolve)
                }
                guard !logs.isEmpty else { return nil }
                return (session, logs)
            }
            .max { lhs, rhs in
                (lhs.0.endTime ?? lhs.0.startTime) < (rhs.0.endTime ?? rhs.0.startTime)
            }
    }

    static func matchesMuscle(
        log: ExerciseLog,
        muscleGroupName: String,
        resolve: (ExerciseSnapshot) -> Exercise?
    ) -> Bool {
        guard let snap = log.workoutExercise.snapshot,
              let ex = resolve(snap) else { return false }
        return ex.targetedMuscles.contains(where: { $0.rawValue == muscleGroupName })
            || (ex.targetedMuscles.isEmpty && muscleGroupName == MuscleGroup.other.rawValue)
    }

    /// Last prescribed work set among the muscle's logs (strength or cardio), skipping warm-ups.
    static func lastWorkingSet(in logs: [ExerciseLog]) -> LoggedSet? {
        logs
            .flatMap(\.loggedSets)
            .filter { $0.countsTowardRecommendedSets || $0.countsTowardCardioTotals }
            .max { $0.timestamp < $1.timestamp }
    }

    /// e.g. `Last working: 185 lb × 8 reps` or `Last working: 45:00 · 6.0 km`.
    static func lastWorkingLine(for logs: [ExerciseLog], unit: WeightDisplayUnit) -> String? {
        guard let set = lastWorkingSet(in: logs) else { return nil }
        let summary: String
        if set.isCardioEntry {
            summary = set.cardioDisplaySummary
        } else {
            summary = set.weightRepsDisplaySummary(displayUnit: unit)
        }
        return "Last working: \(summary)"
    }

    static func relativeDayLabel(
        endingAt end: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(end, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(end, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: end),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days <= 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    /// Muscle-detail header: `Last working: 185 lb × 8 reps · Push A · Today`.
    static func recap(
        session: WorkoutSession,
        logs: [ExerciseLog],
        unit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let line = lastWorkingLine(for: logs, unit: unit) else { return nil }
        let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = session.endTime ?? session.startTime
        let day = relativeDayLabel(endingAt: end, now: now, calendar: calendar)
        if name.isEmpty {
            return "\(line) · \(day)"
        }
        return "\(line) · \(name) · \(day)"
    }

    /// Compact Explore-by-muscle caption from the latest session in range.
    static func exploreLine(
        muscleGroupName: String,
        sessions: [WorkoutSession],
        unit: WeightDisplayUnit,
        resolve: (ExerciseSnapshot) -> Exercise?
    ) -> String? {
        guard let latest = latest(muscleGroupName: muscleGroupName, in: sessions, resolve: resolve) else {
            return nil
        }
        return lastWorkingLine(for: latest.logs, unit: unit)
    }
}
