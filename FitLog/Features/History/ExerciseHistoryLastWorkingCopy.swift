//
//  ExerciseHistoryLastWorkingCopy.swift
//  FitLog
//
//  Last working set for History Explore (by exercise) and exercise detail.
//  Does not unlock Premium charts or change the 14-day History cap.
//

import Foundation

enum ExerciseHistoryLastWorkingCopy {
    /// Latest completed session that logged this exercise (range-limited when `sessions` is).
    static func latestLog(
        exerciseId: UUID,
        in sessions: [WorkoutSession]
    ) -> (session: WorkoutSession, log: ExerciseLog)? {
        sessions
            .compactMap { session -> (WorkoutSession, ExerciseLog)? in
                guard session.isCompleted,
                      let log = session.exerciseLogs.first(where: {
                          $0.workoutExercise.exerciseId == exerciseId
                              || $0.workoutExercise.snapshot?.exerciseId == exerciseId
                      })
                else { return nil }
                return (session, log)
            }
            .max { lhs, rhs in
                (lhs.0.endTime ?? lhs.0.startTime) < (rhs.0.endTime ?? rhs.0.startTime)
            }
    }

    /// Last prescribed work set (strength or cardio), skipping warm-ups.
    static func lastWorkingSet(in log: ExerciseLog) -> LoggedSet? {
        log.loggedSets
            .filter { $0.countsTowardRecommendedSets || $0.countsTowardCardioTotals }
            .max { $0.timestamp < $1.timestamp }
    }

    /// e.g. `Last working: 185 lb × 8 reps` or `Last working: 45:00 · 6.0 km`.
    static func lastWorkingLine(for log: ExerciseLog, unit: WeightDisplayUnit) -> String? {
        guard let set = lastWorkingSet(in: log) else { return nil }
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

    /// Exercise-detail header: `Last working: 185 lb × 8 reps · Push A · Today`.
    static func recap(
        session: WorkoutSession,
        log: ExerciseLog,
        unit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let line = lastWorkingLine(for: log, unit: unit) else { return nil }
        let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = session.endTime ?? session.startTime
        let day = relativeDayLabel(endingAt: end, now: now, calendar: calendar)
        if name.isEmpty {
            return "\(line) · \(day)"
        }
        return "\(line) · \(name) · \(day)"
    }

    /// Compact Explore-by-exercise caption from the latest session in range.
    static func exploreLine(
        exerciseId: UUID,
        sessions: [WorkoutSession],
        unit: WeightDisplayUnit
    ) -> String? {
        guard let latest = latestLog(exerciseId: exerciseId, in: sessions) else { return nil }
        return lastWorkingLine(for: latest.log, unit: unit)
    }
}
