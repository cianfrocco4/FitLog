//
//  HomeStartWorkoutSheetCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct HomeStartWorkoutSheetCopyTests {
    @Test func scheduledSection_recommendedWhenNotLogged() {
        #expect(HomeStartWorkoutSheetCopy.scheduledSectionHeader(isCompletedToday: false) == "Recommended")
        #expect(
            HomeStartWorkoutSheetCopy.scheduledAccessibilityHint(isCompletedToday: false)
                == "Starts today's scheduled workout"
        )
        #expect(
            HomeStartWorkoutSheetCopy.scheduledAccessibilityLabel(
                workoutName: "Push A",
                isCompletedToday: false
            ) == "Today's plan, Push A"
        )
    }

    @Test func scheduledSection_loggedTodayCopy() {
        #expect(HomeStartWorkoutSheetCopy.scheduledSectionHeader(isCompletedToday: true) == "Logged today")
        #expect(
            HomeStartWorkoutSheetCopy.scheduledAccessibilityHint(isCompletedToday: true)
                == "Starts this workout again as a new session"
        )
        #expect(
            HomeStartWorkoutSheetCopy.scheduledAccessibilityLabel(
                workoutName: "Push A",
                isCompletedToday: true
            ) == "Today's plan, Push A, done today"
        )
    }
}
