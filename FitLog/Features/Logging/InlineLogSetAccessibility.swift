//
//  InlineLogSetAccessibility.swift
//  FitLog
//
//  VoiceOver copy for the inline quick-log checkmark control.
//

import Foundation

enum InlineLogSetAccessibility {
    /// Builds a spoken label that includes exercise context and drafted load/reps.
    static func logSetLabel(
        exerciseName: String,
        bodyweightMode: Bool,
        displayWeight: Double,
        reps: Int,
        unitLabel: String,
        formatWeight: (Double) -> String = WeightStoreConversion.formatDisplay
    ) -> String {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let namePart = trimmedName.isEmpty ? nil : trimmedName

        var parts = ["Log set"]
        if let namePart {
            parts.append(namePart)
        }

        if bodyweightMode {
            if displayWeight != 0 {
                let signed: String
                if displayWeight > 0 {
                    signed = "+\(formatWeight(displayWeight))"
                } else {
                    signed = "−\(formatWeight(-displayWeight))"
                }
                parts.append("\(signed) \(unitLabel) net")
            }
        } else if displayWeight > 0 {
            parts.append("\(formatWeight(displayWeight)) \(unitLabel)")
        }

        if reps > 0 {
            parts.append("\(reps) \(reps == 1 ? "rep" : "reps")")
        }

        return parts.joined(separator: ", ")
    }

    static let logSetHint = "Logs the entered weight and reps for this exercise"
}
