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

    @Test func restStepperValueStaysInsideSafeRangeAndStep() {
        #expect(SessionRestOverrideBounds.stepperDisplayValue(-15) == 0)
        #expect(SessionRestOverrideBounds.stepperDisplayValue(90) == 90)
        #expect(SessionRestOverrideBounds.stepperDisplayValue(100) == 90)
        #expect(SessionRestOverrideBounds.stepperDisplayValue(450) == 300)
        #expect(SessionRestOverrideBounds.stepperDisplayValue(600) == 300)
        #expect(SessionRestOverrideBounds.stepperDisplayValue(301) == 300)
    }

    @Test func dismissSettleDelayIsPositiveButShort() {
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds > 0)
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds <= 500_000_000)
    }
}
