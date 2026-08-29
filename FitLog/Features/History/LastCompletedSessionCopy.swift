//
//  LastCompletedSessionCopy.swift
//  FitLog
//
//  Last finished session lines for widgets and History Explore.
//  Does not unlock Premium charts or change the 14-day History cap.
//

import Foundation

enum LastCompletedSessionCopy {
    struct WidgetLines: Equatable {
        let title: String
        let subtitle: String
    }

    static func mostRecentCompleted(
        in sessions: [WorkoutSession]
    ) -> WorkoutSession? {
        sessions
            .filter(\.isCompleted)
            .max { lhs, rhs in
                (lhs.endTime ?? lhs.startTime) < (rhs.endTime ?? rhs.startTime)
            }
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

    static func compactDurationLabel(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return mm == 0 ? "\(h)h" : "\(h)h \(mm)m"
        }
        return "\(m) min"
    }

    static func relativeDayLabel(
        endingAt end: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDateInToday(end) { return "Today" }
        if calendar.isDateInYesterday(end) { return "Yesterday" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: end),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days <= 1 { return "Yesterday" }
        return "\(days)d ago"
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

    /// Widget recap after finish, e.g. title `Zone 2`, subtitle `Today · 45 min`.
    static func widgetLines(
        sessions: [WorkoutSession],
        exercises: [Exercise] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetLines? {
        guard let session = mostRecentCompleted(in: sessions) else { return nil }
        let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let end = session.endTime ?? session.startTime
        var subtitle = relativeDayLabel(endingAt: end, now: now, calendar: calendar)
        if let seconds = preferredDurationSeconds(from: session, exercises: exercises) {
            subtitle += " · \(compactDurationLabel(seconds))"
        }
        return WidgetLines(title: name, subtitle: subtitle)
    }

    /// History Explore caption under the last-date line. Cardio duration wins when present.
    static func exploreRecap(
        latestSession: WorkoutSession,
        exercises: [Exercise] = [],
        unit: WeightDisplayUnit
    ) -> String? {
        if let seconds = preferredDurationSeconds(from: latestSession, exercises: exercises),
           latestSession.workout.workoutKind == .cardio
            || latestSession.workout.workoutKind == .hybrid
            || CardioSessionAggregatesCalculator.aggregates(
                for: latestSession,
                exercises: exercises
            ).hasCardio
        {
            return "Last duration: \(compactDurationLabel(seconds))"
        }
        if let load = lastWorkingLoadLabel(from: latestSession, unit: unit) {
            return "Last working: \(load)"
        }
        if let seconds = preferredDurationSeconds(from: latestSession, exercises: exercises) {
            return "Last duration: \(compactDurationLabel(seconds))"
        }
        return nil
    }
}
