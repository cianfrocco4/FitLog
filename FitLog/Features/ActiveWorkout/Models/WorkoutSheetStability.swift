//
//  WorkoutSheetStability.swift
//  FitLog
//
//  Pure helpers that keep the active-workout pull-up sheet from crashing on
//  collapse, and that step session rest without rewriting the displayed seconds.
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

    /// Step from the real rest value. Results stay inside `range`; the input is not floored,
    /// so a 100s rest stays 100s until the user changes it (100 ± 15 → 115 or 85).
    static func stepped(_ seconds: Int, by direction: Int) -> Int {
        let delta = direction >= 0 ? step : -step
        let next = seconds.addingReportingOverflow(delta)
        let summed = next.overflow ? (direction >= 0 ? range.upperBound : range.lowerBound) : next.partialValue
        return min(range.upperBound, max(range.lowerBound, summed))
    }
}
