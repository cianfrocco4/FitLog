//
//  HistoryTodayLoggedRecap.swift
//  FitLog
//
//  Overview recap of today’s latest completed session (finish → History loop).
//

import Foundation

enum HistoryTodayLoggedRecap {
    struct Recap: Equatable, Identifiable {
        let id: UUID
        let workoutName: String
        let durationSeconds: Int
        let workingSetCount: Int
        let cardioDurationSeconds: Int

        var statsLine: String {
            var parts: [String] = []
            if durationSeconds > 0 {
                parts.append(durationLabel(seconds: durationSeconds))
            }
            if workingSetCount > 0 {
                parts.append(
                    workingSetCount == 1 ? "1 working set" : "\(workingSetCount) working sets"
                )
            } else if cardioDurationSeconds > 0 {
                parts.append(CardioMetricsCalculator.formatDuration(seconds: cardioDurationSeconds))
            }
            return parts.joined(separator: " · ")
        }
    }

    /// Latest completed session that ended on `now`’s calendar day.
    static func recap(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        let candidates = sessions.filter { session in
            guard session.isCompleted, let end = session.endTime else { return false }
            return calendar.isDate(end, inSameDayAs: now)
        }
        guard let session = candidates.max(by: {
            ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime)
        }) else { return nil }

        let end = session.endTime ?? now
        let durationSeconds = max(0, Int(end.timeIntervalSince(session.startTime)))
        let workingSetCount = session.exerciseLogs
            .flatMap(\.loggedSets)
            .filter(\.countsTowardVolumeTotals)
            .count
        let cardioDurationSeconds = session.exerciseLogs
            .flatMap(\.loggedSets)
            .compactMap(\.cardioMetrics?.durationSec)
            .reduce(0, +)

        return Recap(
            id: session.id,
            workoutName: session.workout.name,
            durationSeconds: durationSeconds,
            workingSetCount: workingSetCount,
            cardioDurationSeconds: cardioDurationSeconds
        )
    }

    static func durationLabel(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(clamped)s"
    }
}
