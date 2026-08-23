//
//  HistoryFreePeek.swift
//  FitLog
//
//  Sessions older than the selected History range stay openable in the
//  Sessions list. Charts, KPIs, and Explore stay locked to the range
//  (free tier remains 7–14 days).
//

import Foundation

enum HistoryFreePeek {
    static func olderSectionTitle(range: HistoryDayRange) -> String {
        "Older than \(range.rangeDescription)"
    }

    static func olderSectionFooter(range: HistoryDayRange) -> String {
        "These workouts stay in your log. Charts and trends stay on \(range.rangeDescription)."
    }

    static func emptyInRangeMessage(range: HistoryDayRange) -> String {
        "No workouts completed in the \(range.rangeDescription). Older sessions are listed below."
    }

    static func overviewBannerTitle(count: Int) -> String {
        count == 1 ? "1 older session" : "\(count) older sessions"
    }

    static func overviewBannerDetail(count: Int, range: HistoryDayRange) -> String {
        let noun = count == 1 ? "workout" : "workouts"
        return "You still have \(count) \(noun) from before this range. Open Sessions to view them — charts stay on \(range.rangeDescription)."
    }

    static func overviewBannerAccessibilityLabel(count: Int, range: HistoryDayRange) -> String {
        "\(overviewBannerTitle(count: count)). \(overviewBannerDetail(count: count, range: range))"
    }

    static func overviewBannerAccessibilityHint() -> String {
        "Switches to Sessions so you can open older workouts. Charts stay on the selected range."
    }
}
