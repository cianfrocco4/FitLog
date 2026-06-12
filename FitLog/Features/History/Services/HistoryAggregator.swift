//
//  HistoryAggregator.swift
//  FitLog
//

import Foundation
import SwiftUI

enum HistoryAggregator {
    // MARK: - Session lists

    static func sessionsInDateRange(
        from allSessions: [WorkoutSession],
        cutoff: Date
    ) -> [WorkoutSession] {
        allSessions
            .filter { ($0.endTime ?? Date()) >= cutoff }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    static func allSessionsSorted(from allSessions: [WorkoutSession]) -> [WorkoutSession] {
        allSessions.sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    static func priorSessions(
        from allSessions: [WorkoutSession],
        priorStart: Date,
        priorEnd: Date
    ) -> [WorkoutSession] {
        allSessions.filter { s in
            let d = s.endTime ?? s.startTime
            return d >= priorStart && d < priorEnd
        }
    }

    // MARK: - KPIs

    static func computeKPIs(_ sessions: [WorkoutSession], periodCutoff: Date = .distantPast) -> HistoryKPIs {
        var sets = 0
        var vol = 0.0
        var durSum = 0
        let cal = Calendar.current
        var trainedDays = Set<Date>()

        for s in sessions {
            sets += s.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            vol += s.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.totalVolumeLoad }
            let end = s.endTime ?? s.startTime
            durSum += max(0, Int(end.timeIntervalSince(s.startTime)))
            trainedDays.insert(cal.startOfDay(for: end))
        }

        let avg = sessions.isEmpty ? 0 : durSum / sessions.count

        return HistoryKPIs(
            sessions: sessions.count,
            totalSets: sets,
            totalVolume: vol,
            avgSessionSeconds: avg,
            daysTrained: trainedDays.count
        )
    }

    static func trainedDays(from sessions: [WorkoutSession], calendar: Calendar = .current) -> Set<Date> {
        var trainedDays = Set<Date>()
        for session in sessions where session.isCompleted {
            let end = session.endTime ?? session.startTime
            trainedDays.insert(calendar.startOfDay(for: end))
        }
        return trainedDays
    }

    static func currentTrainingStreak(trainedDays: Set<Date>, calendar: Calendar = .current) -> Int {
        guard !trainedDays.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while trainedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Session summary

    @MainActor
    static func sessionSummary(session: WorkoutSession, dataVM: DataManager) -> HistorySessionSummary {
        let sets = session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
        let volume = session.exerciseLogs.flatMap(\.loggedSets).reduce(0.0) { $0 + $1.totalVolumeLoad }
        let end = session.endTime ?? session.startTime
        let duration = max(0, Int(end.timeIntervalSince(session.startTime)))
        let prKinds = personalRecordKindsForSession(session: session, dataVM: dataVM)
        return HistorySessionSummary(
            setCount: sets,
            volume: volume,
            durationSeconds: duration,
            prKinds: prKinds
        )
    }

    @MainActor
    static func personalRecordKindsForSession(session: WorkoutSession, dataVM: DataManager) -> [PersonalRecordEvent.Kind] {
        var kinds = Set<PersonalRecordEvent.Kind>()
        for log in session.exerciseLogs {
            for set in log.loggedSets {
                for kind in dataVM.personalRecordKindsForHistoricalSet(set: set, log: log, session: session) {
                    kinds.insert(kind)
                }
            }
        }
        return Array(kinds).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Session grouping

    static func groupedSessionSections(_ sessions: [WorkoutSession], calendar: Calendar = .current) -> [HistorySessionSection] {
        guard !sessions.isEmpty else { return [] }

        let now = Date()
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? now

        var thisWeek: [WorkoutSession] = []
        var lastWeek: [WorkoutSession] = []
        var byMonth: [Int: (title: String, sessions: [WorkoutSession])] = [:]

        for session in sessions {
            let date = session.endTime ?? session.startTime
            if date >= startOfThisWeek {
                thisWeek.append(session)
            } else if date >= startOfLastWeek {
                lastWeek.append(session)
            } else {
                let key = monthSortKey(for: date, calendar: calendar)
                let title = date.formatted(.dateTime.month(.wide).year())
                var bucket = byMonth[key] ?? (title: title, sessions: [])
                bucket.sessions.append(session)
                byMonth[key] = bucket
            }
        }

        var sections: [HistorySessionSection] = []
        if !thisWeek.isEmpty {
            sections.append(HistorySessionSection(id: "this-week", title: "This week", sessions: thisWeek))
        }
        if !lastWeek.isEmpty {
            sections.append(HistorySessionSection(id: "last-week", title: "Last week", sessions: lastWeek))
        }
        for key in byMonth.keys.sorted(by: >) {
            if let bucket = byMonth[key], !bucket.sessions.isEmpty {
                sections.append(HistorySessionSection(id: "\(key)", title: bucket.title, sessions: bucket.sessions))
            }
        }
        return sections
    }

    private static func monthSortKey(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return year * 12 + month
    }

    static func contentRevision(for sessions: [WorkoutSession]) -> Int {
        var hasher = Hasher()
        for session in sessions {
            hasher.combine(session.id)
            hasher.combine(session.endTime)
            hasher.combine(session.startTime)
            let setCount = session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            hasher.combine(setCount)
        }
        return hasher.finalize()
    }

    static func weekCount(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        guard let startWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start,
              let endWeek = calendar.dateInterval(of: .weekOfYear, for: end)?.start
        else { return 1 }
        let weeks = calendar.dateComponents([.weekOfYear], from: startWeek, to: endWeek).weekOfYear ?? 0
        return max(1, weeks + 1)
    }

    // MARK: - Heatmap

    static func yearHeatmapDays(from allSessions: [WorkoutSession], calendar: Calendar = .current) -> [YearHeatmapDay] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -364, to: today) else { return [] }
        var countByDay: [Date: Int] = [:]
        for s in allSessions where s.isCompleted {
            let d = calendar.startOfDay(for: s.endTime ?? s.startTime)
            countByDay[d, default: 0] += 1
        }
        var out: [YearHeatmapDay] = []
        var d = start
        while d <= today {
            out.append(YearHeatmapDay(id: d, date: d, sessionCount: countByDay[d] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    static func yearHeatmapWeekColumns(from days: [YearHeatmapDay]) -> [[YearHeatmapDay]] {
        guard !days.isEmpty else { return [] }
        var weeks: [[YearHeatmapDay]] = []
        var row: [YearHeatmapDay] = []
        for day in days {
            row.append(day)
            if row.count == 7 {
                weeks.append(row)
                row = []
            }
        }
        if !row.isEmpty {
            weeks.append(row)
        }
        return weeks
    }

    static func heatmapMonthLabels(for weekColumns: [[YearHeatmapDay]], calendar: Calendar = .current) -> [String?] {
        weekColumns.map { week in
            guard let firstDay = week.first else { return nil }
            let day = calendar.component(.day, from: firstDay.date)
            if day <= 7 {
                return firstDay.date.formatted(.dateTime.month(.abbreviated))
            }
            return nil
        }
    }

    // MARK: - Weekly aggregates

    static func weeklyWorkouts(from sessions: [WorkoutSession], calendar: Calendar = .current) -> [WeekData] {
        var counts: [Date: Int] = [:]
        for session in sessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            counts[weekStart, default: 0] += 1
        }
        return counts
            .map { WeekData(id: $0.key, weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    static func weeklyVolume(from sessions: [WorkoutSession], calendar: Calendar = .current) -> [WeekVolumeData] {
        var volumeByWeek: [Date: Double] = [:]
        for session in sessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let vol = session.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.totalVolumeLoad }
            volumeByWeek[weekStart, default: 0] += vol
        }
        return volumeByWeek
            .map { WeekVolumeData(id: $0.key, weekStart: $0.key, volume: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    static func weeklySetCounts(from sessions: [WorkoutSession], calendar: Calendar = .current) -> [WeekData] {
        var setsByWeek: [Date: Int] = [:]
        for session in sessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let sets = session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            setsByWeek[weekStart, default: 0] += sets
        }
        return setsByWeek
            .map { WeekData(id: $0.key, weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    @MainActor
    static func weeklyCardio(
        from sessions: [WorkoutSession],
        exercises: [Exercise],
        calendar: Calendar = .current
    ) -> [WeekCardioData] {
        var byWeek: [Date: (seconds: Int, meters: Double)] = [:]
        for session in sessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let agg = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: exercises)
            guard agg.hasCardio else { continue }
            var bucket = byWeek[weekStart] ?? (0, 0)
            bucket.seconds += agg.durationSeconds
            bucket.meters += agg.distanceMeters
            byWeek[weekStart] = bucket
        }
        return byWeek
            .map { WeekCardioData(
                id: $0.key,
                weekStart: $0.key,
                minutes: Double($0.value.seconds) / 60.0,
                distanceKm: $0.value.meters / 1000.0
            ) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    static func shiftWeekData(_ rows: [WeekData], by weeks: Int, calendar: Calendar = .current) -> [WeekData] {
        rows.map { row in
            let shifted = calendar.date(byAdding: .weekOfYear, value: weeks, to: row.weekStart) ?? row.weekStart
            return WeekData(id: shifted, weekStart: shifted, count: row.count)
        }
    }

    static func shiftWeekVolumeData(
        _ rows: [WeekVolumeData],
        by weeks: Int,
        calendar: Calendar = .current
    ) -> [WeekVolumeData] {
        rows.map { row in
            let shifted = calendar.date(byAdding: .weekOfYear, value: weeks, to: row.weekStart) ?? row.weekStart
            return WeekVolumeData(id: shifted, weekStart: shifted, volume: row.volume)
        }
    }

    static func shiftWeekCardioData(
        _ rows: [WeekCardioData],
        by weeks: Int,
        calendar: Calendar = .current
    ) -> [WeekCardioData] {
        rows.map { row in
            let shifted = calendar.date(byAdding: .weekOfYear, value: weeks, to: row.weekStart) ?? row.weekStart
            return WeekCardioData(
                id: shifted,
                weekStart: shifted,
                minutes: row.minutes,
                distanceKm: row.distanceKm
            )
        }
    }

    static func nearestWeekStart(_ selected: Date, in weekStarts: [Date]) -> Date? {
        let unique = Array(Set(weekStarts))
        guard !unique.isEmpty else { return nil }
        return unique.min(by: { abs($0.timeIntervalSince(selected)) < abs($1.timeIntervalSince(selected)) })
    }

    // MARK: - Muscle / exercise stats

    @MainActor
    static func muscleGroupVolumeRows(in sessions: [WorkoutSession], dataVM: DataManager) -> [MuscleVolumeRow] {
        var byGroup: [String: Double] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
                let vol = log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                let muscles = ex.targetedMuscles
                if muscles.isEmpty {
                    byGroup[MuscleGroup.other.rawValue, default: 0] += vol
                } else {
                    for m in muscles {
                        byGroup[m.rawValue, default: 0] += vol
                    }
                }
            }
        }
        return byGroup.map { MuscleVolumeRow(name: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }

    @MainActor
    static func resolvedExerciseForHistoryAnalytics(log: ExerciseLog, dataVM: DataManager) -> Exercise? {
        if let snap = log.workoutExercise.snapshot,
           let ex = dataVM.resolveExercise(for: snap) {
            return ex
        }
        if let eid = log.workoutExercise.exerciseId,
           let ex = dataVM.globalExercises.first(where: { $0.id == eid }) {
            return ex
        }
        return nil
    }

    @MainActor
    static func exerciseStats(in sessions: [WorkoutSession], dataVM: DataManager) -> [ExerciseStat] {
        var byId: [UUID: (sample: Exercise, sessions: Set<UUID>, sets: Int, volume: Double)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let ex = resolvedExerciseForHistoryAnalytics(log: log, dataVM: dataVM) else { continue }
                var entry = byId[ex.id] ?? (sample: ex, sessions: [], sets: 0, volume: 0)
                entry.sessions.insert(session.id)
                entry.sets += log.loggedSets.count
                entry.volume += log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                byId[ex.id] = entry
            }
        }
        return byId.map { id, data in
            ExerciseStat(
                id: id,
                sampleExercise: data.sample,
                sessions: data.sessions.count,
                totalSets: data.sets,
                volume: data.volume
            )
        }
    }

    @MainActor
    static func muscleGroupStats(in sessions: [WorkoutSession], dataVM: DataManager) -> [MuscleGroupStat] {
        var byGroup: [String: (sessions: Set<UUID>, exercises: Set<UUID>)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let ex = resolvedExerciseForHistoryAnalytics(log: log, dataVM: dataVM) else { continue }
                let muscles = ex.targetedMuscles
                if muscles.isEmpty {
                    let g = MuscleGroup.other.rawValue
                    var e = byGroup[g] ?? (sessions: [], exercises: [])
                    e.sessions.insert(session.id)
                    e.exercises.insert(ex.id)
                    byGroup[g] = e
                } else {
                    for m in muscles {
                        let key = m.rawValue
                        var e = byGroup[key] ?? (sessions: [], exercises: [])
                        e.sessions.insert(session.id)
                        e.exercises.insert(ex.id)
                        byGroup[key] = e
                    }
                }
            }
        }
        return byGroup.map { name, data in
            MuscleGroupStat(name: name, sessions: data.sessions.count, exerciseCount: data.exercises.count)
        }
    }

    static func bestWorkingEst1RM(for log: ExerciseLog) -> Double? {
        var best = 0.0
        var found = false
        for set in log.loggedSets where set.countsTowardLoadPRMetrics {
            var candidate = HistoryFormatters.epleyEst1RM(weight: set.weight, reps: set.reps)
            for d in set.dropSegments where d.reps > 0 {
                let e = HistoryFormatters.epleyEst1RM(weight: d.weight, reps: d.reps)
                if e > candidate { candidate = e }
            }
            if candidate > best {
                best = candidate
                found = true
            }
        }
        return found ? best : nil
    }

    // MARK: - KPI deltas

    static func deltaLine(current: Int, prior: Int, invert: Bool) -> (String, Color) {
        if prior == 0 {
            if current == 0 { return ("No prior data", .secondary) }
            return ("New vs prior", FitlogPalette.success)
        }
        let p = Int(round(Double(current - prior) / Double(prior) * 100))
        let sign = p > 0 ? "+" : ""
        let color = kpiDeltaColor(percent: p, invert: invert)
        return ("\(sign)\(p)% vs prior", color)
    }

    private static func kpiDeltaColor(percent: Int, invert: Bool) -> Color {
        let p = invert ? -percent : percent
        if p > 0 { return FitlogPalette.success }
        if p < 0 { return FitlogPalette.caution }
        return .secondary
    }
}
