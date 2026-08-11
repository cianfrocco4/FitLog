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

    static func logSetHint(bodyweightMode: Bool) -> String {
        bodyweightMode
            ? "Logs the entered net load and reps for this exercise"
            : "Logs the entered weight and reps for this exercise"
    }

    /// Spoken when the inline checkmark is disabled because reps are missing.
    static var logSetDisabledHint: String {
        "Enter reps greater than zero to log this set"
    }

    /// Shared disabled hint for inline edit-set / drop confirm checkmarks.
    static var confirmDisabledHint: String {
        "Enter reps greater than zero to save"
    }

    static func confirmEditSetLabel(setNumber: Int) -> String {
        "Save edited set \(setNumber)"
    }

    static var confirmEditSetHint: String {
        "Saves changes to this set"
    }

    static var confirmDropSegmentLabel: String {
        "Save drop segment"
    }

    static var confirmDropSegmentHint: String {
        "Saves this drop segment"
    }

    /// Past-tense confirmation announced after a successful inline quick-log.
    static func loggedSetAnnouncement(
        exerciseName: String,
        bodyweightMode: Bool,
        displayWeight: Double,
        reps: Int,
        unitLabel: String,
        isDropSegment: Bool = false,
        formatWeight: (Double) -> String = WeightStoreConversion.formatDisplay
    ) -> String {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let namePart = trimmedName.isEmpty ? nil : trimmedName

        var parts = [isDropSegment ? "Logged drop" : "Logged set"]
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
}
