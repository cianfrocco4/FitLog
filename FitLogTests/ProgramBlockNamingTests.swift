//
//  ProgramBlockNamingTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class ProgramBlockNamingTests: XCTestCase {
    func testPrefixedDayName_addsBlockLabelForMultiBlock() {
        let name = ProgramBlockNaming.materializedWorkoutName(
            dayName: "Push A",
            blockName: "Phase 1: Build muscle",
            isMultiBlock: true
        )
        XCTAssertEqual(name, "Phase 1: Push A")
    }

    func testPrefixedDayName_skipsPrefixForSingleBlock() {
        let name = ProgramBlockNaming.materializedWorkoutName(
            dayName: "Push A",
            blockName: "Phase 1: Build muscle",
            isMultiBlock: false
        )
        XCTAssertEqual(name, "Push A")
    }

    func testPrefixedDayName_avoidsDoublePrefix() {
        let name = ProgramBlockNaming.prefixedDayName(
            dayName: "Phase 1: Push A",
            blockName: "Phase 1: Build muscle"
        )
        XCTAssertEqual(name, "Phase 1: Push A")
    }

    func testApplyBlockPrefixIfNeeded_onlyWhenMultiBlock() {
        let templates = [
            BlockWeeklyTemplate(dayName: "Pull", focus: "", slots: [])
        ]
        let single = ProgramBlockNaming.applyBlockPrefixIfNeeded(
            to: templates,
            blockName: "Strength",
            isMultiBlock: false
        )
        XCTAssertEqual(single[0].dayName, "Pull")

        let multi = ProgramBlockNaming.applyBlockPrefixIfNeeded(
            to: templates,
            blockName: "Strength",
            isMultiBlock: true
        )
        XCTAssertEqual(multi[0].dayName, "Strength: Pull")
    }
}
