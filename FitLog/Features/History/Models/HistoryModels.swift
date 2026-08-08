//
//  HistoryModels.swift
//  FitLog
//

import Foundation

// MARK: - Time range & main tab

enum HistoryDayRange: Hashable, Identifiable, CaseIterable {
    case d7, d14, d30, d90, ytd

    var id: Self { self }

    static let defaultRange: HistoryDayRange = .d14

    /// Ranges available on the free tier.
    static let freeTierCases: [HistoryDayRange] = [.d7, .d14]

    /// Default range for free-tier users on first launch.
    static let freeTierDefault: HistoryDayRange = .d14

    var requiresPremium: Bool {
        !Self.freeTierCases.contains(self)
    }

    /// Returns a range allowed for the user's subscription tier.
    static func effectiveRange(selected: HistoryDayRange, isPremium: Bool) -> HistoryDayRange {
        guard !isPremium, selected.requiresPremium else { return selected }
        return freeTierDefault
    }

    /// Whether applying `selected` is allowed for the current subscription tier (no mutation).
    static func allowsSelection(_ selected: HistoryDayRange, isPremium: Bool) -> Bool {
        PremiumGatedSelection.shouldApply(requiresPremium: selected.requiresPremium, hasPremiumAccess: isPremium)
    }

    var menuLabel: String {
        switch self {
        case .d7: return "Last 7 days"
        case .d14: return "Last 14 days"
        case .d30: return "Last 30 days"
        case .d90: return "Last 90 days"
        case .ytd: return "Year to date"
        }
    }

    var rangeDescription: String {
        switch self {
        case .d7: return "last 7 days"
        case .d14: return "last 14 days"
        case .d30: return "last 30 days"
        case .d90: return "last 90 days"
        case .ytd: return "year to date"
        }
    }

    var emptySessionsMessage: String {
        switch self {
        case .ytd: return "No workouts completed year to date"
        default: return "No workouts completed in the \(rangeDescription)"
        }
    }

    func cutoff(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .d7: return now.addingTimeInterval(-7 * 86400)
        case .d14: return now.addingTimeInterval(-14 * 86400)
        case .d30: return now.addingTimeInterval(-30 * 86400)
        case .d90: return now.addingTimeInterval(-90 * 86400)
        case .ytd:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
    }

    /// Window immediately before the current range, same length (for compare).
    func priorWindow(from now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date)? {
        switch self {
        case .d7, .d14, .d30, .d90:
            let days: Double = {
                switch self {
                case .d7: return 7
                case .d14: return 14
                case .d30: return 30
                case .d90: return 90
                case .ytd: return 0
                }
            }()
            let currentStart = now.addingTimeInterval(-days * 86400)
            let priorStart = now.addingTimeInterval(-2 * days * 86400)
            return (priorStart, currentStart)
        case .ytd:
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            let len = now.timeIntervalSince(startOfYear)
            let priorEnd = startOfYear
            let priorStart = priorEnd.addingTimeInterval(-len)
            return (priorStart, priorEnd)
        }
    }

    /// Whole-week shift to align prior-period week buckets onto the current chart x-axis.
    func priorToCurrentWeekShift(from now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let (priorStart, _) = priorWindow(from: now, calendar: calendar) else { return nil }
        let currentStart = cutoff(from: now, calendar: calendar)
        let priorWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: priorStart)
        ) ?? priorStart
        let currentWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentStart)
        ) ?? currentStart
        return calendar.dateComponents([.weekOfYear], from: priorWeekStart, to: currentWeekStart).weekOfYear
    }
}

enum HistoryMainTab: String, CaseIterable, Identifiable {
    case overview, sessions, explore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .sessions: return "Sessions"
        case .explore: return "Explore"
        }
    }
}

struct HistoryKPIs: Equatable {
    let sessions: Int
    let totalSets: Int
    let totalVolume: Double
    let avgSessionSeconds: Int
    let daysTrained: Int

    static let empty = HistoryKPIs(
        sessions: 0,
        totalSets: 0,
        totalVolume: 0,
        avgSessionSeconds: 0,
        daysTrained: 0
    )
}

struct HistorySessionSummary: Equatable {
    let setCount: Int
    let volume: Double
    let durationSeconds: Int
    let prKinds: [PersonalRecordEvent.Kind]
}

struct YearHeatmapDay: Identifiable {
    let id: Date
    let date: Date
    let sessionCount: Int
}

struct MuscleVolumeRow: Identifiable {
    let name: String
    let volume: Double
    var id: String { name }
}

struct WeekData: Identifiable {
    let id: Date
    let weekStart: Date
    let count: Int
}

struct WeekVolumeData: Identifiable {
    let id: Date
    let weekStart: Date
    let volume: Double
}

struct WeekCardioData: Identifiable {
    let id: Date
    let weekStart: Date
    let minutes: Double
    let distanceKm: Double
}

struct WorkoutDurationPoint: Identifiable {
    let id: UUID
    let date: Date
    let minutes: Int
}

struct ExerciseProgressionPoint: Identifiable {
    let id: UUID
    let date: Date
    let estOneRM: Double
}

struct ExerciseVolumePoint: Identifiable {
    let id: UUID
    let date: Date
    let volumeLbRep: Double
}

struct MuscleSessionVolumePoint: Identifiable {
    let id: UUID
    let date: Date
    let volume: Double
}

enum ExerciseHistoryDataScope: String, CaseIterable {
    case selectedRange
    case allTime

    var label: String {
        switch self {
        case .selectedRange: return "Selected range"
        case .allTime: return "All time"
        }
    }

    var requiresPremium: Bool { self == .allTime }

    /// Whether applying `selected` is allowed for the current subscription tier (no mutation).
    static func allowsSelection(_ selected: ExerciseHistoryDataScope, isPremium: Bool) -> Bool {
        PremiumGatedSelection.shouldApply(requiresPremium: selected.requiresPremium, hasPremiumAccess: isPremium)
    }
}

struct ExerciseStat: Identifiable {
    let id: UUID
    let sampleExercise: Exercise
    let sessions: Int
    let totalSets: Int
    let volume: Double
}

struct MuscleGroupStat {
    let name: String
    let sessions: Int
    let exerciseCount: Int
}

struct HistorySessionSection: Identifiable {
    let id: String
    let title: String
    let sessions: [WorkoutSession]
}
