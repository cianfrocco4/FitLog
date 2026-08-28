//
//  SessionLastWorkingSetCopy.swift
//  FitLog
//
//  Last prescribed (non–warm-up) set line for History session detail.
//

import Foundation

enum SessionLastWorkingSetCopy {
    /// Last set that counts as work (strength prescription or cardio volume), skipping warm-ups.
    static func lastWorkingSet(in log: ExerciseLog) -> LoggedSet? {
        log.loggedSets.last { set in
            set.countsTowardRecommendedSets || set.countsTowardCardioTotals
        }
    }

    /// e.g. `Last working: 185 lb × 8 reps` or `Last working: 45:00 · 6.0 km`.
    static func line(for log: ExerciseLog, unit: WeightDisplayUnit) -> String? {
        guard let set = lastWorkingSet(in: log) else { return nil }
        let summary: String
        if set.isCardioEntry {
            summary = set.cardioDisplaySummary
        } else {
            summary = set.weightRepsDisplaySummary(displayUnit: unit)
        }
        return "Last working: \(summary)"
    }
}
