//
//  WorkoutCompletionAnnouncement.swift
//  FitLog
//
//  VoiceOver summary when the workout-complete sheet appears.
//

import Foundation

enum WorkoutCompletionAnnouncement {
    /// Short spoken overview of the finished workout (duration, sets, volume, PRs).
    static func message(
        summary: WorkoutCompletionSummary,
        displayUnit: WeightDisplayUnit,
        formatVolume: (Double, WeightDisplayUnit) -> String = { pounds, unit in
            let vol = WeightStoreConversion.displayValue(storedPounds: pounds, unit: unit)
            return "\(String(format: "%.0f", vol)) \(unit.shortLabel)"
        }
    ) -> String {
        let name = summary.workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = ["Workout complete"]
        if !name.isEmpty {
            parts.append(name)
        }
        parts.append("Duration \(summary.durationFormatted)")
        parts.append(
            "\(summary.totalSets) working \(summary.totalSets == 1 ? "set" : "sets")"
        )
        parts.append("Volume \(formatVolume(summary.totalVolumePounds, displayUnit))")
        if summary.personalRecordCount > 0 {
            let n = summary.personalRecordCount
            parts.append("\(n) personal record \(n == 1 ? "set" : "sets")")
        }
        return parts.joined(separator: ". ")
    }
}
