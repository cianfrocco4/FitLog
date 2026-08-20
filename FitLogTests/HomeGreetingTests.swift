//
//  HomeGreetingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct HomeGreetingTests {
    @Test func alreadyTrained_leadsSubtitleOnUnscheduledDay() {
        let text = HomeGreeting.contextualSubtitle(
            plan: .unscheduled,
            weekGlance: nil,
            scheduledWorkoutName: nil,
            hasCompletedSessionToday: true
        )
        #expect(text.hasPrefix("You already trained today"))
        #expect(text.contains("extra volume"))
    }

    @Test func alreadyTrained_namesPlannedWorkoutWhenDone() {
        let text = HomeGreeting.contextualSubtitle(
            plan: .workout(.workout(UUID())),
            weekGlance: nil,
            scheduledWorkoutName: "Push A",
            hasCompletedSessionToday: true
        )
        #expect(text.hasPrefix("You already trained today"))
        #expect(text.contains("Push A"))
        #expect(text.contains("done"))
    }

    @Test func alreadyTrained_restDayAcknowledgesSession() {
        let text = HomeGreeting.contextualSubtitle(
            plan: .rest,
            weekGlance: nil,
            scheduledWorkoutName: nil,
            hasCompletedSessionToday: true
        )
        #expect(text.hasPrefix("You already trained today"))
        #expect(text.contains("recovery"))
    }

    @Test func withoutSession_keepsScheduleCopy() {
        let text = HomeGreeting.contextualSubtitle(
            plan: .workout(.workout(UUID())),
            weekGlance: nil,
            scheduledWorkoutName: "Pull B",
            hasCompletedSessionToday: false
        )
        #expect(text == "Pull B is on the schedule today.")
    }

    @Test func firstName_usesLeadingToken() {
        #expect(HomeGreeting.firstName(from: "Alex Rivera") == "Alex")
        #expect(HomeGreeting.firstName(from: "  ") == nil)
    }
}
