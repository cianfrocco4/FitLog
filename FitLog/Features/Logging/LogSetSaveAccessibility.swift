//
//  LogSetSaveAccessibility.swift
//  FitLog
//
//  Save-button enablement and VoiceOver copy for the Log Set sheet.
//

import Foundation

enum LogSetSaveAccessibility {
    /// Whether the confirmation Save control should be enabled.
    static func canSave(
        reps: Int,
        bodyweightMode: Bool,
        dropSetEnabled: Bool,
        hasValidDropSegments: Bool,
        isSaving: Bool
    ) -> Bool {
        guard !isSaving else { return false }
        guard reps > 0 else { return false }
        if !bodyweightMode && dropSetEnabled && !hasValidDropSegments {
            return false
        }
        return true
    }

    /// Hint explaining why Save is disabled, or what Save will do when enabled.
    static func saveHint(
        reps: Int,
        bodyweightMode: Bool,
        dropSetEnabled: Bool,
        hasValidDropSegments: Bool,
        isSaving: Bool
    ) -> String {
        if isSaving {
            return "Saving your set"
        }
        if reps <= 0 {
            return "Enter reps greater than zero to save"
        }
        if !bodyweightMode && dropSetEnabled && !hasValidDropSegments {
            return "Add at least one drop with reps greater than zero, or turn off drop set"
        }
        return "Saves this set and returns to the workout"
    }
}
