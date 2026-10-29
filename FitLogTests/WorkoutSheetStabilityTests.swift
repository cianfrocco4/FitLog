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
        #expect(SessionRestOverrideBounds.range == 0...600)
        #expect(SessionRestOverrideBounds.stepped(100, by: 1) == 115)
        #expect(SessionRestOverrideBounds.stepped(100, by: -1) == 85)
        #expect(SessionRestOverrideBounds.stepped(90, by: 1) == 105)
        #expect(SessionRestOverrideBounds.stepped(0, by: -1) == 0)
        #expect(SessionRestOverrideBounds.stepped(300, by: 1) == 315)
        #expect(SessionRestOverrideBounds.stepped(590, by: 1) == 600)
        #expect(SessionRestOverrideBounds.stepped(600, by: 1) == 600)
        #expect(SessionRestOverrideBounds.stepped(600, by: -1) == 585)
        #expect(SessionRestOverrideBounds.stepped(1_000, by: -1) == 600)
        #expect(SessionRestOverrideBounds.stepped(-15, by: 1) == 0)
        #expect(SessionRestOverrideBounds.stepped(1_000, by: 1) == 600)
        #expect(SessionRestOverrideBounds.clamped(1_000) == 600)
        #expect(SessionRestOverrideBounds.clamped(-4) == 0)
        #expect(SessionRestOverrideBounds.clamped(90) == 90)
        for sample in [0, 1, 14, 15, 90, 100, 300, 585, 590, 600] {
            let up = SessionRestOverrideBounds.stepped(sample, by: 1)
            let down = SessionRestOverrideBounds.stepped(sample, by: -1)
            #expect(up >= sample)
            #expect(up - sample <= SessionRestOverrideBounds.step)
            #expect(down <= sample)
            #expect(sample - down <= SessionRestOverrideBounds.step)
        }
    }

    @Test func dismissSettleDelayIsPositiveButShort() {
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds > 0)
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds <= 500_000_000)
    }
}
