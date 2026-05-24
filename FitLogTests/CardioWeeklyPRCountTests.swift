//
//  CardioWeeklyPRCountTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

/// Verifies cross-session cardio PR detection logic used by `weeklyPersonalRecordCount`.
final class CardioWeeklyPRCountTests: XCTestCase {

    func testSecondSessionSameDistanceIsNotPR() {
        let exerciseId = UUID()
        let priorMax = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: .distantPast,
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1200, distanceM: 5000, source: .manual)
        )
        let newSet = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1300, distanceM: 5000, source: .manual)
        )
        let events = PersonalRecordDetector.detectCardio(
            newSet: newSet,
            priorSets: [priorMax],
            exerciseId: exerciseId,
            exerciseName: "Run"
        )
        XCTAssertFalse(events.contains { $0.kind == .maxDistance })
    }

    func testIntervalRestSetCountsAsCardioEntry() {
        let rest = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .intervalRest,
            cardioMetrics: CardioMetrics(durationSec: 60, source: .timer)
        )
        XCTAssertTrue(rest.isCardioEntry)
        XCTAssertFalse(rest.countsTowardCardioTotals)
    }
}
