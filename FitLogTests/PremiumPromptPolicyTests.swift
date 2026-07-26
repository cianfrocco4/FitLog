//
//  PremiumPromptPolicyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct PremiumPromptPolicyTests {

    @Test func postWorkout_requiresThreeCompletionsAndOnceEver() {
        #expect(
            !PremiumPromptPolicy.shouldPresentPostWorkoutPaywall(
                isPremium: false,
                hasSeen: false,
                completedCount: 2
            )
        )
        #expect(
            PremiumPromptPolicy.shouldPresentPostWorkoutPaywall(
                isPremium: false,
                hasSeen: false,
                completedCount: 3
            )
        )
        #expect(
            !PremiumPromptPolicy.shouldPresentPostWorkoutPaywall(
                isPremium: false,
                hasSeen: true,
                completedCount: 10
            )
        )
        #expect(
            !PremiumPromptPolicy.shouldPresentPostWorkoutPaywall(
                isPremium: true,
                hasSeen: false,
                completedCount: 10
            )
        )
    }

    @Test func homeCard_hiddenWhenPremiumDismissedOrSnoozed() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(
            PremiumPromptPolicy.shouldShowHomePremiumCard(
                isPremium: false,
                dismissed: false,
                snoozeUntil: nil,
                now: now
            )
        )
        #expect(
            !PremiumPromptPolicy.shouldShowHomePremiumCard(
                isPremium: true,
                dismissed: false,
                snoozeUntil: nil,
                now: now
            )
        )
        #expect(
            !PremiumPromptPolicy.shouldShowHomePremiumCard(
                isPremium: false,
                dismissed: true,
                snoozeUntil: nil,
                now: now
            )
        )
        #expect(
            !PremiumPromptPolicy.shouldShowHomePremiumCard(
                isPremium: false,
                dismissed: false,
                snoozeUntil: now.addingTimeInterval(3600),
                now: now
            )
        )
        #expect(
            PremiumPromptPolicy.shouldShowHomePremiumCard(
                isPremium: false,
                dismissed: false,
                snoozeUntil: now.addingTimeInterval(-60),
                now: now
            )
        )
    }

    @Test func homeCardSnoozeDeadline_isFourteenDaysAhead() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deadline = PremiumPromptPolicy.homeCardSnoozeDeadline(from: now)
        let days = Calendar.current.dateComponents([.day], from: now, to: deadline).day
        #expect(days == PremiumPromptPolicy.homeCardSnoozeDays)
    }
}
