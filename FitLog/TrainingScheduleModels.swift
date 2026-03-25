//
//  TrainingScheduleModels.swift
//  FitLog
//

import Foundation

// MARK: - Overrides

enum ScheduleDayIntent: String, Codable, Equatable {
    case inherit
    case rest
    case workout
}

struct ScheduleDayOverride: Codable, Equatable {
    var intent: ScheduleDayIntent
    var workoutId: UUID?

    init(intent: ScheduleDayIntent, workoutId: UUID? = nil) {
        self.intent = intent
        self.workoutId = workoutId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        intent = (try? c.decode(ScheduleDayIntent.self, forKey: .intent)) ?? .inherit
        workoutId = try? c.decode(UUID.self, forKey: .workoutId)
    }

    private enum CodingKeys: String, CodingKey {
        case intent, workoutId
    }
}

/// Overrides for one ISO week: keys are weekday integers `1...7` (`Calendar.Component.weekday`).
struct ScheduleWeekOverride: Codable, Equatable {
    var weekdayOverrides: [String: ScheduleDayOverride]

    init(weekdayOverrides: [String: ScheduleDayOverride] = [:]) {
        self.weekdayOverrides = weekdayOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekdayOverrides = (try? c.decode([String: ScheduleDayOverride].self, forKey: .weekdayOverrides)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case weekdayOverrides
    }
}

// MARK: - Program state

struct TrainingProgramState: Codable, Equatable {
    /// Ordered cycle of workout template IDs.
    var cycleWorkoutIds: [UUID]
    var sessionsPerWeek: Int
    /// Empty = default training-day pool (Mon–Fri). Values are `Calendar.Component.weekday` (1 = Sunday … 7 = Saturday).
    var preferredWeekdays: [Int]
    /// `yyyy-MM-dd` in the user’s current calendar, start-of-day semantics for anchoring the rotation.
    var anchorDayKey: String
    var dayOverrides: [String: ScheduleDayOverride]
    var weekOverrides: [String: ScheduleWeekOverride]

    static func empty(anchorDayKey: String) -> TrainingProgramState {
        TrainingProgramState(
            cycleWorkoutIds: [],
            sessionsPerWeek: 3,
            preferredWeekdays: [],
            anchorDayKey: anchorDayKey,
            dayOverrides: [:],
            weekOverrides: [:]
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: date)
        let y = calendar.component(.year, from: d)
        let m = calendar.component(.month, from: d)
        let day = calendar.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var comp = DateComponents()
        comp.year = y
        comp.month = m
        comp.day = d
        return calendar.date(from: comp).map { calendar.startOfDay(for: $0) }
    }

    /// e.g. `2025-W12` using the calendar’s `yearForWeekOfYear` / `weekOfYear`.
    static func isoWeekKey(for date: Date, calendar: Calendar = .current) -> String {
        let y = calendar.component(.yearForWeekOfYear, from: date)
        let w = calendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", y, w)
    }

    /// Start-of-day for each day in the `weekOfYear` interval containing `date`, ordered from `interval.start` (same as Plan tab / week override editor).
    static func orderedCalendarDaysInWeek(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var d = interval.start
        var out: [Date] = []
        while d < interval.end {
            out.append(calendar.startOfDay(for: d))
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    init(
        cycleWorkoutIds: [UUID],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDayKey: String,
        dayOverrides: [String: ScheduleDayOverride],
        weekOverrides: [String: ScheduleWeekOverride]
    ) {
        self.cycleWorkoutIds = cycleWorkoutIds
        self.sessionsPerWeek = sessionsPerWeek
        self.preferredWeekdays = preferredWeekdays
        self.anchorDayKey = anchorDayKey
        self.dayOverrides = dayOverrides
        self.weekOverrides = weekOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cycleWorkoutIds = (try? c.decode([UUID].self, forKey: .cycleWorkoutIds)) ?? []
        sessionsPerWeek = (try? c.decode(Int.self, forKey: .sessionsPerWeek)) ?? 3
        preferredWeekdays = (try? c.decode([Int].self, forKey: .preferredWeekdays)) ?? []
        anchorDayKey = (try? c.decode(String.self, forKey: .anchorDayKey)) ?? Self.dayKey(for: Date())
        dayOverrides = (try? c.decode([String: ScheduleDayOverride].self, forKey: .dayOverrides)) ?? [:]
        weekOverrides = (try? c.decode([String: ScheduleWeekOverride].self, forKey: .weekOverrides)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case cycleWorkoutIds, sessionsPerWeek, preferredWeekdays, anchorDayKey, dayOverrides, weekOverrides
    }
}

// MARK: - Resolved assignment (for UI)

enum ResolvedScheduleDay: Equatable {
    case rest
    case unscheduled
    case workout(UUID)
}
