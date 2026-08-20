//
//  CoachLocalTipGeneratorTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct CoachLocalTipGeneratorTests {
    @Test func trainedToday_leadsWithCompletionNotPaywallCopy() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: "Push A",
            lastWorkoutIsCardio: false,
            lastWorkoutDurationMinutes: nil,
            daysSinceLastWorkout: 0,
            sessionsThisWeek: 1,
            weeklyGoal: 4,
            todayPlan: .unscheduled,
            libraryCount: 3
        ))
        #expect(tip.title == "Already trained today")
        #expect(tip.body.contains("Push A"))
        #expect(!tip.body.localizedCaseInsensitiveContains("premium"))
    }

    @Test func trainedTodayCardio_includesDuration() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: "Zone 2",
            lastWorkoutIsCardio: true,
            lastWorkoutDurationMinutes: 42,
            daysSinceLastWorkout: 0,
            sessionsThisWeek: 1,
            weeklyGoal: 3,
            todayPlan: .rest,
            libraryCount: 1
        ))
        #expect(tip.title == "Already trained today")
        #expect(tip.body.contains("42 min"))
    }

    @Test func lastCardio_surfacesMinutesWithoutOpeningHistory() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: "Zone 2",
            lastWorkoutIsCardio: true,
            lastWorkoutDurationMinutes: 35,
            daysSinceLastWorkout: 1,
            sessionsThisWeek: 2,
            weeklyGoal: 3,
            todayPlan: .unscheduled,
            libraryCount: 1
        ))
        #expect(tip.title == "Last cardio")
        #expect(tip.body.contains("35 min"))
        #expect(tip.body.contains("yesterday"))
    }

    @Test func longGap_suggestsEasingBack() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: "Pull B",
            lastWorkoutIsCardio: false,
            lastWorkoutDurationMinutes: nil,
            daysSinceLastWorkout: 6,
            sessionsThisWeek: 0,
            weeklyGoal: 4,
            todayPlan: .workout("Push A"),
            libraryCount: 3
        ))
        #expect(tip.title == "Ease back in")
        #expect(tip.body.contains("6 days"))
        #expect(tip.body.contains("Pull B"))
    }

    @Test func behindWeeklyGoal_countsSessions() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: "Push A",
            lastWorkoutIsCardio: false,
            lastWorkoutDurationMinutes: nil,
            daysSinceLastWorkout: 2,
            sessionsThisWeek: 1,
            weeklyGoal: 4,
            todayPlan: .unscheduled,
            libraryCount: 3
        ))
        #expect(tip.title == "This week's sessions")
        #expect(tip.body.contains("1 of 4"))
    }

    @Test func restDay_staysQuiet() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: nil,
            lastWorkoutIsCardio: false,
            lastWorkoutDurationMinutes: nil,
            daysSinceLastWorkout: nil,
            sessionsThisWeek: 0,
            weeklyGoal: 0,
            todayPlan: .rest,
            libraryCount: 2
        ))
        #expect(tip.title == "Rest day")
        #expect(tip.body.localizedCaseInsensitiveContains("sleep") || tip.body.localizedCaseInsensitiveContains("walk"))
    }

    @Test func singleLibraryWorkout_nudgesSecondDay() {
        let tip = CoachLocalTipGenerator.tip(from: .init(
            lastWorkoutName: nil,
            lastWorkoutIsCardio: false,
            lastWorkoutDurationMinutes: nil,
            daysSinceLastWorkout: nil,
            sessionsThisWeek: 0,
            weeklyGoal: 0,
            todayPlan: .unscheduled,
            libraryCount: 1
        ))
        #expect(tip.title == "Build a second day")
        #expect(tip.body.contains("Pull") || tip.body.contains("Legs"))
    }
}
