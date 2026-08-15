//
//  WorkoutSessionCompactChromeAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct WorkoutSessionCompactChromeAccessibilityTests {

    @Test func detailsToggleLabel_reflectsExpandedState() {
        #expect(
            WorkoutSessionCompactChromeAccessibility.detailsToggleLabel(detailsExpanded: false)
                == "Expand session details"
        )
        #expect(
            WorkoutSessionCompactChromeAccessibility.detailsToggleLabel(detailsExpanded: true)
                == "Collapse session details"
        )
    }

    @Test func detailsToggleValue_includesMetricsAndOptionalVolume() {
        #expect(
            WorkoutSessionCompactChromeAccessibility.detailsToggleValue(
                workoutName: "Push Day",
                elapsedFormatted: "12:34",
                setsLogged: 4,
                volumeSummary: ""
            ) == "Push Day, 12:34, 4 sets"
        )
        #expect(
            WorkoutSessionCompactChromeAccessibility.detailsToggleValue(
                workoutName: "Push Day",
                elapsedFormatted: "12:34",
                setsLogged: 4,
                volumeSummary: "1,200 lb"
            ) == "Push Day, 12:34, 4 sets, 1,200 lb"
        )
    }

    @Test func pauseResumeCopy_matchesCollapsedBar() {
        #expect(
            WorkoutSessionCompactChromeAccessibility.pauseResumeLabel(isPaused: false)
                == "Pause workout"
        )
        #expect(
            WorkoutSessionCompactChromeAccessibility.pauseResumeHint(isPaused: true)
                == "Resumes the workout timer"
        )
    }
}
