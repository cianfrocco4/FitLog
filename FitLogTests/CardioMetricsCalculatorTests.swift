//
//  CardioMetricsCalculatorTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CardioMetricsCalculatorTests: XCTestCase {

    func testSpokenDuration_minutesAndSeconds() {
        XCTAssertEqual(
            CardioMetricsCalculator.spokenDuration(seconds: 125),
            "2 minutes, 5 seconds"
        )
    }

    func testSpokenDuration_hours() {
        XCTAssertEqual(
            CardioMetricsCalculator.spokenDuration(seconds: 3661),
            "1 hour, 1 minute, 1 second"
        )
    }

    func testFormatDuration_underOneHour() {
        XCTAssertEqual(CardioMetricsCalculator.formatDuration(seconds: 125), "2:05")
    }

    func testFormatDuration_withHours() {
        XCTAssertEqual(CardioMetricsCalculator.formatDuration(seconds: 3661), "1:01:01")
    }

    func testFormatDistance_meters() {
        XCTAssertEqual(CardioMetricsCalculator.formatDistance(meters: 850), "850 m")
    }

    func testFormatDistance_kilometers() {
        XCTAssertEqual(CardioMetricsCalculator.formatDistance(meters: 5200), "5.20 km")
    }

    func testFormatPace() {
        XCTAssertEqual(CardioMetricsCalculator.formatPace(secPerKm: 305), "5:05 /km")
    }

    func testPrescriptionSummary_steadyState() {
        let rx = CardioPrescription(
            kind: .steadyState,
            targetDurationSec: 2700,
            targetDistanceM: 5000,
            targetZone: .zone2
        )
        let summary = CardioMetricsCalculator.prescriptionSummary(rx)
        XCTAssertTrue(summary.contains("Steady"))
        XCTAssertTrue(summary.contains("45:00"))
        XCTAssertTrue(summary.contains("5.00 km"))
        XCTAssertTrue(summary.contains("Zone 2"))
    }

    func testPrescriptionSummary_intervals() {
        let rx = CardioPrescription(
            kind: .intervals,
            intervals: [
                CardioIntervalSpec(workDurationSec: 60, restDurationSec: 30, repeatCount: 8)
            ]
        )
        let summary = CardioMetricsCalculator.prescriptionSummary(rx)
        XCTAssertTrue(summary.contains("interval"))
        XCTAssertTrue(summary.contains("60s work"))
        XCTAssertTrue(summary.contains("30s rest"))
    }
}
