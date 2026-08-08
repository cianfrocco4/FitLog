//
//  CoachScheduleSyncTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CoachScheduleSyncTests: XCTestCase {

    func testDeselectingDaysClampsSessionsImmediately() {
        let result = CoachScheduleSync.toggleWeekday(
            2,
            sessions: 4,
            weekdays: [1, 2, 3, 4]
        )
        XCTAssertEqual(result.weekdays.count, 3)
        XCTAssertEqual(result.sessions, 3)
    }

    func testSelectingDaysDoesNotAutoBumpSessions() {
        let result = CoachScheduleSync.toggleWeekday(
            5,
            sessions: 2,
            weekdays: [1, 3]
        )
        XCTAssertEqual(result.weekdays.count, 3)
        XCTAssertEqual(result.sessions, 2)
    }

    func testClearingAllDaysKeepsSessions() {
        var weekdays: Set<Int> = [1]
        var sessions = 1
        let cleared = CoachScheduleSync.toggleWeekday(1, sessions: sessions, weekdays: weekdays)
        weekdays = cleared.weekdays
        sessions = cleared.sessions
        XCTAssertTrue(weekdays.isEmpty)
        XCTAssertEqual(sessions, 1)
    }

    func testReconcileClampsMismatchedPrefs() {
        let result = CoachScheduleSync.reconcile(sessions: 5, weekdays: [1, 3])
        XCTAssertEqual(result.sessions, 2)
        XCTAssertEqual(result.weekdays, [1, 3])
    }

    func testEmptyWeekdaysAllowUpToSeven() {
        XCTAssertEqual(CoachScheduleSync.maxSessions(for: Set<Int>()), 7)
        XCTAssertEqual(CoachScheduleSync.clampSessions(6, to: Set<Int>()), 6)
    }

    func testOrderedWeekdaysRespectFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        let ordered = CoachScheduleSync.orderedWeekdayNumbers(calendar: calendar)
        XCTAssertEqual(ordered.first, 2)
        XCTAssertEqual(ordered.count, 7)
        XCTAssertEqual(Set(ordered), Set(1 ... 7))
    }
}
