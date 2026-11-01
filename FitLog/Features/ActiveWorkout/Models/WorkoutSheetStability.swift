//
//  WorkoutSheetStability.swift
//  FitLog
//
//  Pure helpers that keep the active-workout pull-up sheet readable and stable:
//  collapse dismiss, opaque presentation fill, finish-ready detection, and
//  session rest steps that do not rewrite the displayed seconds.
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

enum WorkoutSheetPresentationStyle {
    /// Solid fill so logging copy stays readable over the tab bar (user feedback:
    /// the default glass sheet is hard to digest mid-set).
    static var background: Color { Color(.systemBackground) }
}

enum WorkoutFinishReadyPolicy {
    static let bannerTitle = "All sets logged"
    static let bannerSubtitle = "Finish to save this workout to History."
    static let bannerAccessibilityLabel = "All sets logged. Finish to save this workout to History."

    /// True when every startable row has its prescribed work in (or was marked done),
    /// there is at least one startable row, and no open placeholders remain.
    static func shouldOfferFinish(
        logs: [ExerciseLog],
        completedExerciseIds: [UUID]
    ) -> Bool {
        guard !logs.isEmpty else { return false }
        if logs.contains(where: { $0.workoutExercise.isSlotPlaceholder }) { return false }
        let completed = Set(completedExerciseIds)
        return logs.allSatisfy { isRowReady($0, completedExerciseIds: completed) }
    }

    static func isRowReady(
        _ log: ExerciseLog,
        completedExerciseIds: Set<UUID>
    ) -> Bool {
        if log.workoutExercise.isSlotPlaceholder { return false }
        if let id = log.workoutExercise.exerciseId, completedExerciseIds.contains(id) {
            return true
        }
        if log.meetsRecommendedSets { return true }
        return hasCompletedCardioWork(log)
    }

    static func hasCompletedCardioWork(_ log: ExerciseLog) -> Bool {
        log.loggedSets.contains { set in
            set.countsTowardCardioTotals && (set.cardioMetrics?.durationSec ?? 0) > 0
        }
    }
}

enum SessionRestOverrideBounds {
    /// Same limits as the plan editor. Capping session rest at 300 made one minus tap
    /// on a 600s plan rest store 300s.
    static let range: ClosedRange<Int> = 0...600
    static let step: Int = 15

    static func clamped(_ seconds: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, seconds))
    }

    /// Step from the real rest value. Results stay inside `range`; the input is not floored,
    /// so a 100s rest stays 100s until the user changes it (100 ± 15 → 115 or 85).
    static func stepped(_ seconds: Int, by direction: Int) -> Int {
        let delta = direction >= 0 ? step : -step
        let next = seconds.addingReportingOverflow(delta)
        let summed = next.overflow ? (direction >= 0 ? range.upperBound : range.lowerBound) : next.partialValue
        return clamped(summed)
    }
}
