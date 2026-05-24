//
//  CardioPersonalRecordDetectorTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CardioPersonalRecordDetectorTests: XCTestCase {
    func testDetectsLongestDurationPR() {
        let prior = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1200, source: .manual)
        )
        let new = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1500, source: .manual)
        )
        let events = PersonalRecordDetector.detectCardio(
            newSet: new,
            priorSets: [prior],
            exerciseId: UUID(),
            exerciseName: "Run"
        )
        XCTAssertTrue(events.contains { $0.kind == .longestDuration })
    }

    func testDetectsMaxDistancePR() {
        let prior = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1200, distanceM: 4000, source: .manual)
        )
        let new = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 1300, distanceM: 5200, source: .manual)
        )
        let events = PersonalRecordDetector.detectCardio(
            newSet: new,
            priorSets: [prior],
            exerciseId: UUID(),
            exerciseName: "Run"
        )
        XCTAssertTrue(events.contains { $0.kind == .maxDistance })
    }

    func testDetectsBestPacePR() {
        let prior = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 600, distanceM: 2000, avgPaceSecPerKm: 300, source: .manual)
        )
        let new = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 600, distanceM: 2500, avgPaceSecPerKm: 240, source: .manual)
        )
        let events = PersonalRecordDetector.detectCardio(
            newSet: new,
            priorSets: [prior],
            exerciseId: UUID(),
            exerciseName: "Run"
        )
        XCTAssertTrue(events.contains { $0.kind == .bestPace })
    }
}
