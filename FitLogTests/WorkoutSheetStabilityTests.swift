//
//  WorkoutSheetStabilityTests.swift
//  FitLogTests
//

import SwiftUI
import Testing
@testable import FitLog

struct WorkoutSheetStabilityTests {
    @Test func collapsedDetentDismissesPullUp() {
        #expect(WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.collapsed))
        #expect(!WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.medium))
        #expect(!WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.expanded))
    }

    @Test func restStepsFromActualSecondsAndClampsTheResult() {
        #expect(SessionRestOverrideBounds.stepped(100, by: 1) == 115)
        #expect(SessionRestOverrideBounds.stepped(100, by: -1) == 85)
        #expect(SessionRestOverrideBounds.stepped(90, by: 1) == 105)
        #expect(SessionRestOverrideBounds.stepped(0, by: -1) == 0)
        #expect(SessionRestOverrideBounds.stepped(300, by: 1) == 300)
        #expect(SessionRestOverrideBounds.stepped(600, by: -1) == 300)
        #expect(SessionRestOverrideBounds.stepped(-15, by: 1) == 0)
    }

    @Test func dismissSettleDelayIsPositiveButShort() {
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds > 0)
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds <= 500_000_000)
    }
}
