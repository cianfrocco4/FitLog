//
//  CoachScheduleSync.swift
//  FitLog
//
//  Shared sessions-per-week ↔ preferred-weekday reconciliation for Guided Coach
//  and Advanced Builder.
//

import Foundation

enum CoachScheduleSync {
    /// Maximum sessions allowed for the current weekday selection.
    /// Empty weekdays means no day preference — allow up to 7.
    static func maxSessions(for weekdays: Set<Int>) -> Int {
        weekdays.isEmpty ? 7 : weekdays.count
    }

    static func maxSessions(for weekdays: [Int]) -> Int {
        maxSessions(for: Set(weekdays.filter { $0 >= 1 && $0 <= 7 }))
    }

    /// Clamp sessions into a valid range for the given weekday selection.
    static func clampSessions(_ sessions: Int, to weekdays: Set<Int>) -> Int {
        let maxAllowed = maxSessions(for: weekdays)
        return min(maxAllowed, max(1, sessions))
    }

    static func clampSessions(_ sessions: Int, to weekdays: [Int]) -> Int {
        clampSessions(sessions, to: Set(weekdays.filter { $0 >= 1 && $0 <= 7 }))
    }

    /// Toggle a weekday and return the reconciled sessions + weekdays pair.
    /// Deselecting clamps sessions down; selecting never auto-bumps sessions up.
    static func toggleWeekday(
        _ day: Int,
        sessions: Int,
        weekdays: Set<Int>
    ) -> (sessions: Int, weekdays: Set<Int>) {
        guard (1 ... 7).contains(day) else {
            return (clampSessions(sessions, to: weekdays), weekdays)
        }
        var next = weekdays
        if next.contains(day) {
            next.remove(day)
        } else {
            next.insert(day)
        }
        return (clampSessions(sessions, to: next), next)
    }

    /// Final reconcile before persisting intake / blueprint schedule.
    static func reconcile(sessions: Int, weekdays: [Int]) -> (sessions: Int, weekdays: [Int]) {
        let cleaned = weekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        return (clampSessions(sessions, to: cleaned), cleaned)
    }

    /// Weekday numbers 1…7 rotated so the first matches `Calendar.firstWeekday`.
    static func orderedWeekdayNumbers(calendar: Calendar = .current) -> [Int] {
        let first = calendar.firstWeekday
        return (0 ..< 7).map { ((first - 1 + $0) % 7) + 1 }
    }

    /// Short weekday symbol for a Gregorian weekday number (1 = Sunday … 7 = Saturday).
    static func shortSymbol(for weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.shortWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "\(weekday)" }
        return symbols[weekday - 1]
    }
}
