//
//  ReadinessLastTrainedCopy.swift
//  FitLog
//
//  One-line last-session recap for the Home readiness card.
//

import Foundation

enum ReadinessLastTrainedCopy {
    /// Latest completed session, e.g. `Last trained today · Push A`.
    static func line(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let completed = sessions.filter(\.isCompleted)
        guard let session = completed.max(by: {
            ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime)
        }) else { return nil }

        let end = session.endTime ?? session.startTime
        let start = calendar.startOfDay(for: end)
        let ref = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: ref).day ?? 0
        let when: String
        if days <= 0 {
            when = "today"
        } else if days == 1 {
            when = "yesterday"
        } else {
            when = "\(days)d ago"
        }
        return "Last trained \(when) · \(session.workout.name)"
    }
}
