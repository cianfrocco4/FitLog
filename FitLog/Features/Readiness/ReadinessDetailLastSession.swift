//
//  ReadinessDetailLastSession.swift
//  FitLog
//
//  Last finished session recap for Readiness details (widget deep-link landing).
//  Does not change Home readiness card copy or widget payload fields.
//

import Foundation

enum ReadinessDetailLastSession {
    static func mostRecentCompleted(in sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions
            .filter(\.isCompleted)
            .max { lhs, rhs in
                (lhs.endTime ?? lhs.startTime) < (rhs.endTime ?? rhs.startTime)
            }
    }

    static func relativeDayPhrase(
        endingAt end: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let start = calendar.startOfDay(for: end)
        let ref = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: ref).day ?? 0
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(days)d ago"
    }

    /// e.g. `Last trained yesterday · Push A`.
    static func recapLine(
        session: WorkoutSession,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = session.endTime ?? session.startTime
        let when = relativeDayPhrase(endingAt: end, now: now, calendar: calendar)
        if name.isEmpty {
            return "Last trained \(when)"
        }
        return "Last trained \(when) · \(name)"
    }

    static func compactDurationLabel(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return mm == 0 ? "\(h)h" : "\(h)h \(mm)m"
        }
        return "\(m) min"
    }

    /// Prefer logged cardio minutes; otherwise wall-clock for any completed session.
    static func preferredDurationSeconds(
        from session: WorkoutSession,
        exercises: [Exercise] = []
    ) -> Int? {
        let cardio = CardioSessionAggregatesCalculator.aggregates(
            for: session,
            exercises: exercises
        ).durationSeconds
        if cardio >= 30 { return cardio }
        guard let end = session.endTime else { return nil }
        let wall = Int(end.timeIntervalSince(session.startTime))
        return wall >= 30 ? wall : nil
    }

    /// Last load-PR set (skips warm-ups, timed holds, cardio), most recent timestamp.
    static func lastWorkingLoadLabel(
        from session: WorkoutSession,
        unit: WeightDisplayUnit
    ) -> String? {
        var latest: LoggedSet?
        for log in session.exerciseLogs {
            for set in log.loggedSets where set.countsTowardLoadPRMetrics && set.weight > 0 {
                if let current = latest {
                    if set.timestamp >= current.timestamp {
                        latest = set
                    }
                } else {
                    latest = set
                }
            }
        }
        guard let set = latest else { return nil }
        let displayed = WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
        let weightText = displayed == floor(displayed)
            ? "\(Int(displayed))"
            : String(format: "%.1f", displayed)
        return "\(weightText) \(unit.shortLabel) × \(set.reps)"
    }

    /// Second line under the recap: last working load, else last duration.
    static func detailLine(
        session: WorkoutSession,
        exercises: [Exercise] = [],
        unit: WeightDisplayUnit
    ) -> String? {
        if let load = lastWorkingLoadLabel(from: session, unit: unit) {
            return "Last working: \(load)"
        }
        if let seconds = preferredDurationSeconds(from: session, exercises: exercises) {
            return "Last duration: \(compactDurationLabel(seconds))"
        }
        return nil
    }
}
