//
//  WorkoutSessionCompactChromeAccessibility.swift
//  FitLog
//
//  VoiceOver copy for the collapsible active-session chrome header.
//

import Foundation

enum WorkoutSessionCompactChromeAccessibility {
    /// Label for the expand/collapse control.
    static func detailsToggleLabel(detailsExpanded: Bool) -> String {
        detailsExpanded ? "Collapse session details" : "Expand session details"
    }

    /// Spoken summary of the compact header metrics.
    static func detailsToggleValue(
        workoutName: String,
        elapsedFormatted: String,
        setsLogged: Int,
        volumeSummary: String
    ) -> String {
        var parts: [String] = [workoutName, elapsedFormatted, "\(setsLogged) sets"]
        let trimmedVolume = volumeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVolume.isEmpty {
            parts.append(trimmedVolume)
        }
        return parts.joined(separator: ", ")
    }

    /// Hint for the expand/collapse control.
    static func detailsToggleHint(detailsExpanded: Bool) -> String {
        detailsExpanded
            ? "Hides workout notes"
            : "Shows workout notes and more session details"
    }

    /// Label for pause/resume in the compact chrome.
    static func pauseResumeLabel(isPaused: Bool) -> String {
        isPaused ? "Resume workout" : "Pause workout"
    }

    /// Hint for pause/resume in the compact chrome.
    static func pauseResumeHint(isPaused: Bool) -> String {
        isPaused ? "Resumes the workout timer" : "Pauses the workout timer"
    }
}
