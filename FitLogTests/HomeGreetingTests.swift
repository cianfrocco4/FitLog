//
//  HomeGreetingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeGreetingTests {
    @Test func contextualSubtitle_appendsLastWorkingWeightForPlannedDay() {
        let subtitle = HomeGreeting.contextualSubtitle(
            plan: .workout(.workout(UUID())),
            weekGlance: nil,
            scheduledWorkoutName: "Push A",
            lastWorkingWeightLabel: "185 lb"
        )
        #expect(subtitle == "Push A is on the schedule today · last 185 lb.")
    }

    @Test func contextualSubtitle_omitsWeightWhenMissing() {
        let subtitle = HomeGreeting.contextualSubtitle(
            plan: .workout(.workout(UUID())),
            weekGlance: nil,
            scheduledWorkoutName: "Push A"
        )
        #expect(subtitle == "Push A is on the schedule today.")
    }
}
