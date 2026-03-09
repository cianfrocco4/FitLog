//
//  HistoryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var dataVM: DataManager
    @State private var selectedDays: Int = 7

    private let dayOptions = [7, 14, 30]

    private var sessionsInRange: [WorkoutSession] {
        let cutoff = Date().addingTimeInterval(-Double(selectedDays) * 24 * 60 * 60)
        return dataVM.completedSessions.filter { ($0.endTime ?? Date()) >= cutoff }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Last", selection: $selectedDays) {
                        ForEach(dayOptions, id: \.self) { n in
                            Text("\(n) days").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Time range")
                }

                trendsChartsSection
                workoutsCompletedSection
                workoutAnalyticsSection
                exerciseAnalyticsSection
                muscleGroupAnalyticsSection
            }
            .navigationTitle("History & Analytics")
            .onAppear {
                dataVM.refreshCompletedSessions()
            }
        }
    }

    // MARK: - Trend charts (weekly aggregates)
    private var trendsChartsSection: some View {
        Section {
            if sessionsInRange.isEmpty {
                Text("Complete workouts to see trends")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    workoutsPerWeekChart
                    volumePerWeekChart
                    setsPerWeekChart
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Trends")
        }
    }

    private var workoutsPerWeekChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workouts per week")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Chart(weeklyWorkoutCounts) { row in
                BarMark(
                    x: .value("Week", row.weekStart),
                    y: .value("Workouts", row.count)
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 160)
        }
    }

    private var volumePerWeekChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Volume per week (lb·rep)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Chart(weeklyVolume) { row in
                BarMark(
                    x: .value("Week", row.weekStart),
                    y: .value("Volume", row.volume)
                )
                .foregroundStyle(.orange.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 160)
        }
    }

    private var setsPerWeekChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sets per week")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Chart(weeklySetCounts) { row in
                BarMark(
                    x: .value("Week", row.weekStart),
                    y: .value("Sets", row.count)
                )
                .foregroundStyle(.green.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 160)
        }
    }

    private struct WeekData: Identifiable {
        let id: Date
        let weekStart: Date
        let count: Int
    }

    private struct WeekVolumeData: Identifiable {
        let id: Date
        let weekStart: Date
        let volume: Double
    }

    private var weeklyWorkoutCounts: [WeekData] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessionsInRange) { session -> Date in
            let d = session.endTime ?? session.startTime
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
        }
        return grouped
            .map { WeekData(id: $0.key, weekStart: $0.key, count: $0.value.count) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private var weeklyVolume: [WeekVolumeData] {
        let calendar = Calendar.current
        var volumeByWeek: [Date: Double] = [:]
        for session in sessionsInRange {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let vol = session.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.weight * Double($1.reps) }
            volumeByWeek[weekStart, default: 0] += vol
        }
        return volumeByWeek
            .map { WeekVolumeData(id: $0.key, weekStart: $0.key, volume: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private var weeklySetCounts: [WeekData] {
        let calendar = Calendar.current
        var setsByWeek: [Date: Int] = [:]
        for session in sessionsInRange {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let sets = session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            setsByWeek[weekStart, default: 0] += sets
        }
        return setsByWeek
            .map { WeekData(id: $0.key, weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }
    
    // MARK: - Workouts completed in last N days
    private var workoutsCompletedSection: some View {
        Section {
            if sessionsInRange.isEmpty {
                Text("No workouts completed in the last \(selectedDays) days")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionsInRange) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.workout.name)
                                    .font(.headline)
                                Text(formatDate(session.endTime ?? session.startTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(durationString(for: session))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Workouts completed (last \(selectedDays) days)")
        }
    }
    
    // MARK: - Workout-level analytics (sessions per workout in range)
    private var workoutAnalyticsSection: some View {
        Section {
            let grouped = Dictionary(grouping: sessionsInRange) { $0.workout.id }
            let sorted = grouped.sorted { ($1.value.first?.endTime ?? .distantPast) > ($0.value.first?.endTime ?? .distantPast) }
            if sorted.isEmpty {
                Text("No workout data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted, id: \.key) { workoutId, sessions in
                    let name = sessions.first?.workout.name ?? "Unknown"
                    let last = sessions.map(\.endTime).compactMap { $0 }.max()
                    NavigationLink(destination: WorkoutHistoryDetailView(sessions: sessions, workoutName: name)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.headline)
                                if let last = last {
                                    Text("Last: \(formatDate(last))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("By workout")
        }
    }
    
    // MARK: - Exercise-level analytics (in range)
    private var exerciseAnalyticsSection: some View {
        Section {
            let stats = exerciseStats(in: sessionsInRange)
            if stats.isEmpty {
                Text("No exercise data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.name) { stat in
                    NavigationLink(destination: ExerciseHistoryDetailView(exerciseName: stat.name, sessions: sessionsInRange)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.name)
                                .font(.headline)
                            HStack(spacing: 16) {
                                Label("\(stat.sessions) session\(stat.sessions == 1 ? "" : "s")", systemImage: "calendar")
                                Label("\(stat.totalSets) sets", systemImage: "square.stack.3d.up")
                                if stat.volume > 0 {
                                    Label("\(Int(stat.volume)) lb·rep", systemImage: "scalemass")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("By exercise")
        }
    }
    
    // MARK: - Muscle group analytics (in range)
    private var muscleGroupAnalyticsSection: some View {
        Section {
            let stats = muscleGroupStats(in: sessionsInRange)
            if stats.isEmpty {
                Text("No muscle group data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.name) { stat in
                    NavigationLink(destination: MuscleGroupHistoryDetailView(muscleGroupName: stat.name, sessions: sessionsInRange)) {
                        HStack {
                            Text(stat.name)
                                .font(.headline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(stat.sessions) session\(stat.sessions == 1 ? "" : "s")")
                                Text("\(stat.exerciseCount) exercise\(stat.exerciseCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        } header: {
            Text("By muscle group")
        }
    }
    
    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func durationString(for session: WorkoutSession) -> String {
        let end = session.endTime ?? session.startTime
        let secs = Int(end.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private struct ExerciseStat {
        let name: String
        let sessions: Int
        let totalSets: Int
        let volume: Double
    }
    
    private func exerciseStats(in sessions: [WorkoutSession]) -> [ExerciseStat] {
        var byName: [String: (sessions: Set<UUID>, sets: Int, volume: Double)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                let name = log.workoutExercise.exercise.name
                var entry = byName[name] ?? (sessions: [], sets: 0, volume: 0)
                entry.sessions.insert(session.id)
                entry.sets += log.loggedSets.count
                entry.volume += log.loggedSets.reduce(0) { $0 + Double($1.reps) * $1.weight }
                byName[name] = entry
            }
        }
        return byName.map { name, data in
            ExerciseStat(name: name, sessions: data.sessions.count, totalSets: data.sets, volume: data.volume)
        }
    }
    
    private struct MuscleGroupStat {
        let name: String
        let sessions: Int
        let exerciseCount: Int
    }
    
    private func muscleGroupStats(in sessions: [WorkoutSession]) -> [MuscleGroupStat] {
        var byGroup: [String: (sessions: Set<UUID>, exercises: Set<UUID>)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                let muscles = log.workoutExercise.exercise.targetedMuscles
                if muscles.isEmpty {
                    let g = MuscleGroup.other.rawValue
                    var e = byGroup[g] ?? (sessions: [], exercises: [])
                    e.sessions.insert(session.id)
                    e.exercises.insert(log.workoutExercise.exercise.id)
                    byGroup[g] = e
                } else {
                    for m in muscles {
                        let key = m.rawValue
                        var e = byGroup[key] ?? (sessions: [], exercises: [])
                        e.sessions.insert(session.id)
                        e.exercises.insert(log.workoutExercise.exercise.id)
                        byGroup[key] = e
                    }
                }
            }
        }
        return byGroup.map { name, data in
            MuscleGroupStat(name: name, sessions: data.sessions.count, exerciseCount: data.exercises.count)
        }
    }
}

// MARK: - Session detail (single workout session: exercises + logged sets)
private struct SessionDetailView: View {
    let session: WorkoutSession

    private var endDate: Date { session.endTime ?? session.startTime }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(HistoryView.formatDateStatic(endDate))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(HistoryView.durationStringStatic(for: session))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(session.exerciseLogs) { log in
                let ex = log.workoutExercise.exercise
                Section(log.workoutExercise.exercise.name) {
                    ForEach(log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(set.weight)) lb × \(set.reps) rep\(set.reps == 1 ? "" : "s")")
                                if set.isWarmup {
                                    Text("Warm-up")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Spacer()
                            }
                            if !set.configurationSummary(options: ex.configurationOptions).isEmpty {
                                Text(set.configurationSummary(options: ex.configurationOptions))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(session.workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Workout history (list of sessions for one workout)
private struct WorkoutHistoryDetailView: View {
    let sessions: [WorkoutSession]
    let workoutName: String

    private var sortedSessions: [WorkoutSession] {
        sessions.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    var body: some View {
        List(sortedSessions) { session in
            NavigationLink(destination: SessionDetailView(session: session)) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(HistoryView.formatDateStatic(session.endTime ?? session.startTime))
                            .font(.headline)
                        Text("\(session.exerciseLogs.count) exercise\(session.exerciseLogs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(HistoryView.durationStringStatic(for: session))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise history (each session where exercise was done + logged sets)
private struct ExerciseHistoryDetailView: View {
    let exerciseName: String
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, log: ExerciseLog)] {
        sessions.compactMap { session in
            guard let log = session.exerciseLogs.first(where: { $0.workoutExercise.exercise.name == exerciseName }) else { return nil }
            return (session, log)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    var body: some View {
        List {
            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.log.loggedSets) { set in
                        let ex = item.log.workoutExercise.exercise
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(set.weight)) lb × \(set.reps) rep\(set.reps == 1 ? "" : "s")")
                                if set.isWarmup {
                                    Text("Warm-up")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Spacer()
                            }
                            if !set.configurationSummary(options: ex.configurationOptions).isEmpty {
                                Text(set.configurationSummary(options: ex.configurationOptions))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Muscle group history (sessions + exercises that targeted this muscle + sets)
private struct MuscleGroupHistoryDetailView: View {
    let muscleGroupName: String
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, logs: [ExerciseLog])] {
        sessions.compactMap { session in
            let logs = session.exerciseLogs.filter { log in
                log.workoutExercise.exercise.targetedMuscles.contains(where: { $0.rawValue == muscleGroupName })
                    || (log.workoutExercise.exercise.targetedMuscles.isEmpty && muscleGroupName == MuscleGroup.other.rawValue)
            }
            if logs.isEmpty { return nil }
            return (session, logs)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    var body: some View {
        List {
            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.logs) { log in
                        let ex = log.workoutExercise.exercise
                        DisclosureGroup(log.workoutExercise.exercise.name) {
                            ForEach(log.loggedSets) { set in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(Int(set.weight)) lb × \(set.reps) rep\(set.reps == 1 ? "" : "s")")
                                        if set.isWarmup {
                                            Text("Warm-up")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.quaternary, in: Capsule())
                                        }
                                        Spacer()
                                    }
                                    if !set.configurationSummary(options: ex.configurationOptions).isEmpty {
                                        Text(set.configurationSummary(options: ex.configurationOptions))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(muscleGroupName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared formatters (used by detail views)
extension HistoryView {
    static func formatDateStatic(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func durationStringStatic(for session: WorkoutSession) -> String {
        let end = session.endTime ?? session.startTime
        let secs = Int(end.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}
