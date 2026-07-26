//
//  WeeklyInsightCache.swift
//  FitLog
//
//  UserDefaults cache for weekly NL insights (avoid V7 unless needed).
//

import Foundation

enum WeeklyInsightCache {
    private static let prefix = "fitlog.weeklyInsight."

    static func weekKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? calendar.component(.year, from: date)
        let week = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }

    static func load(weekKey: String, defaults: UserDefaults = .standard) -> WeeklyInsight? {
        guard let data = defaults.data(forKey: prefix + weekKey) else { return nil }
        return try? JSONDecoder().decode(WeeklyInsight.self, from: data)
    }

    static func save(_ insight: WeeklyInsight, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(insight) else { return }
        defaults.set(data, forKey: prefix + insight.weekKey)
    }
}
