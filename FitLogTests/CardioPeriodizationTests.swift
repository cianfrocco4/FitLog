//
//  CardioPeriodizationTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CardioPeriodizationTests: XCTestCase {
    func testDeloadScalesDurationDown() {
        let base = CardioPrescription(kind: .steadyState, targetDurationSec: 3600)
        let ctx = BlockContext(
            blockId: UUID(),
            focus: BlockFocus(kind: .endurance, emphasisLabel: ""),
            volumeMultiplier: 1.0,
            progressionStrategy: .linear,
            weekIndexInBlock: 0,
            isDeloadBlock: true,
            blockDurationWeeks: 4
        )
        let scaled = CardioPeriodization.scaledPrescription(base, blockContext: ctx)
        XCTAssertEqual(scaled.targetDurationSec, 2520)
    }

    func testVolumeMultiplierScalesDistance() {
        let base = CardioPrescription(kind: .steadyState, targetDistanceM: 10_000)
        let ctx = BlockContext(
            blockId: UUID(),
            focus: BlockFocus(kind: .endurance, emphasisLabel: ""),
            volumeMultiplier: 1.1,
            progressionStrategy: .linear,
            weekIndexInBlock: 2,
            isDeloadBlock: false,
            blockDurationWeeks: 6
        )
        let scaled = CardioPeriodization.scaledPrescription(base, blockContext: ctx)
        XCTAssertEqual(scaled.targetDistanceM ?? 0, 11_000, accuracy: 0.1)
    }
}
