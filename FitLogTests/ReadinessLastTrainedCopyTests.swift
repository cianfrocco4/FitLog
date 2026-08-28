//
//  ReadinessLastTrainedCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct ReadinessLastTrainedCopyTests {
    private let calendar = Calendar.current
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12))!

    @Test func line_todayUsesLatestCompletedName() {
        let morning = session(name: "Push A", endOffsetHours: -8)
        let evening = session(name: "Pull A", endOffsetHours: -1)
        #expect(
            ReadinessLastTrainedCopy.line(
                from: [morning, evening],
                now: now,
                calendar: calendar
            ) == "Last trained today · Pull A"
        )
    }

    @Test func line_yesterdayAndOlder() {
        let yesterday = session(name: "Zone 2", endOffsetHours: -26)
        #expect(
            ReadinessLastTrainedCopy.line(
                from: [yesterday],
                now: now,
                calendar: calendar
            ) == "Last trained yesterday · Zone 2"
        )

        let older = session(name: "Legs", endOffsetHours: -24 * 4)
        #expect(
            ReadinessLastTrainedCopy.line(
                from: [older],
                now: now,
                calendar: calendar
            ) == "Last trained 4d ago · Legs"
        )
    }

    @Test func line_nilWhenNothingCompleted() {
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Live", exercises: []),
            startTime: now.addingTimeInterval(-600),
            endTime: nil,
            exerciseLogs: []
        )
        #expect(
            ReadinessLastTrainedCopy.line(
                from: [live],
                now: now,
                calendar: calendar
            ) == nil
        )
        #expect(ReadinessLastTrainedCopy.line(from: [], now: now, calendar: calendar) == nil)
    }

    private func session(name: String, endOffsetHours: Int) -> WorkoutSession {
        let end = now.addingTimeInterval(TimeInterval(endOffsetHours * 3600))
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: []),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: []
        )
    }
}
