//
//  PremiumPromptPolicy.swift
//  FitLog
//
//  Centralized predicates for organic Premium prompts (avoid ad-hoc spam rules).
//

import Foundation

enum PremiumPromptPolicy {
    /// Completed workouts required before the one-time post-workout paywall.
    static let postWorkoutMinimumCompletedSessions = 3

    /// Days to hide the Home Premium card after “Remind me later”.
    static let homeCardSnoozeDays = 14

    /// Once-ever sheet after workout completion summary (not first-session spam).
    static func shouldPresentPostWorkoutPaywall(
        isPremium: Bool,
        hasSeen: Bool,
        completedCount: Int
    ) -> Bool {
        guard !isPremium else { return false }
        guard !hasSeen else { return false }
        return completedCount >= postWorkoutMinimumCompletedSessions
    }

    /// Dismissible / snoozable Home teaser for free users.
    static func shouldShowHomePremiumCard(
        isPremium: Bool,
        dismissed: Bool,
        snoozeUntil: Date?,
        completedSessionCount: Int = 0,
        now: Date = .now
    ) -> Bool {
        guard !isPremium else { return false }
        guard !dismissed else { return false }
        guard completedSessionCount >= 1 else { return false }
        if let snoozeUntil, snoozeUntil > now { return false }
        return true
    }

    static func homeCardSnoozeDeadline(from now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: homeCardSnoozeDays, to: now) ?? now.addingTimeInterval(TimeInterval(homeCardSnoozeDays * 24 * 60 * 60))
    }
}
