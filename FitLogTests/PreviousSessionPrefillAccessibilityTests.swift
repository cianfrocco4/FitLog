//
//  PreviousSessionPrefillAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct PreviousSessionPrefillAccessibilityTests {

    @Test func pillLabelIncludesWeightUnitAndReps() {
        let label = PreviousSessionPrefillAccessibility.pillLabel(
            weightDisplay: "185",
            unitLabel: "lb",
            reps: 8
        )
        #expect(label == "Use previous set 185 lb × 8")
    }

    @Test func pillHintExplainsPrefill() {
        #expect(
            PreviousSessionPrefillAccessibility.pillHint
                == "Fills weight and reps for the next set"
        )
    }
}
