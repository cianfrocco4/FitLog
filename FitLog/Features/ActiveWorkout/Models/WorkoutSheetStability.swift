//
//  WorkoutSheetStability.swift
//  FitLog
//
//  Pure helpers that keep the active-workout pull-up sheet from crashing on
//  collapse / Notes-and-rest expansion (invalid Stepper values).
//

import Foundation
import SwiftUI

enum WorkoutSheetCollapsePolicy {
    /// Collapsed detent means “minimize to the floating bar” — dismiss the sheet
    /// after the detent gesture settles (see `MainTabView`).
    static func shouldDismissPullUp(for detent: PresentationDetent) -> Bool {
        detent == FitlogWorkoutSheetDetent.collapsed
    }

    /// Delay before tearing down the sheet so SwiftUI can finish the detent animation.
    static let dismissSettleNanoseconds: UInt64 = 150_000_000
}

enum SessionRestOverrideBounds {
    static let range: ClosedRange<Int> = 0...300
    static let step: Int = 15

    /// SwiftUI `Stepper` crashes when `value` is outside `in:` or not aligned to `step`.
    static func stepperDisplayValue(_ seconds: Int) -> Int {
        let clamped = min(range.upperBound, max(range.lowerBound, seconds))
        let aligned = (clamped / step) * step
        return min(range.upperBound, max(range.lowerBound, aligned))
    }
}
