//
//  HistoryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI
import Charts

private enum HistorySessionOriginFilter: String, CaseIterable, Identifiable {
    case all
    case concreteAndOlder
    case slotTemplate

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .concreteAndOlder: return "Routines"
        case .slotTemplate: return "Templates"
        }
    }

    var footerExplanation: String {
        switch self {
        case .all:
            return "Analytics use every completed session in the time range."
        case .concreteAndOlder:
            return "Saved workout routines and older sessions logged before source tracking."
        case .slotTemplate:
            return "Only sessions started from a flexible template on Plan."
        }
    }

    func includes(_ session: WorkoutSession) -> Bool {
        switch self {
        case .all: return true
        case .concreteAndOlder:
            switch session.sessionPlanOrigin {
            case nil, .concreteWorkout: return true
            case .slotTemplate: return false
            }
        case .slotTemplate:
            if case .slotTemplate = session.sessionPlanOrigin { return true }
            return false
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var dataVM: DataManager
    @State private var selectedDays: Int = 7
    @State private var sessionOriginFilter: HistorySessionOriginFilter = .all

    private let dayOptions = [7, 14, 30]

    private var sessionsInDateRange: [WorkoutSession] {
        let cutoff = Date().addingTimeInterval(-Double(selectedDays) * 24 * 60 * 60)
        return dataVM.completedSessions.filter { ($0.endTime ?? Date()) >= cutoff }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    private var filteredSessions: [WorkoutSession] {
        sessionsInDateRange.filter { sessionOriginFilter.includes($0) }
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
                    Picker("Session source", selection: $sessionOriginFilter) {
                        ForEach(HistorySessionOriginFilter.allCases) { f in
                            Text(f.shortLabel).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Time range")
                } footer: {
                    Text(sessionOriginFilter.footerExplanation)
                        .font(.caption2)
                }

                trendsChartsSection
                workoutsCompletedSection
                workoutAnalyticsSection
                exerciseAnalyticsSection
                muscleGroupAnalyticsSection
            }
            .fitlogWorkoutBarContentInset()
            .navigationTitle("History & Analytics")
            .onAppear {
                dataVM.refreshCompletedSessions()
            }
        }
    }

    // MARK: - Trend charts (weekly aggregates)
    private var trendsChartsSection: some View {
        Section {
            if filteredSessions.isEmpty {
                Text(sessionsInDateRange.isEmpty ? "Complete workouts to see trends" : "No sessions match this source filter")
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
            Chart(weeklyWorkoutsByOrigin) { row in
                BarMark(
                    x: .value("Week", row.weekStart),
                    y: .value("Workouts", row.count)
                )
                .foregroundStyle(by: .value("Source", row.segment))
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
            Chart(weeklyVolumeFiltered) { row in
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
            Chart(weeklySetCountsFiltered) { row in
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

    private struct WeekOriginBar: Identifiable {
        let id: String
        let weekStart: Date
        let segment: String
        let count: Int
    }

    private struct WeekVolumeData: Identifiable {
        let id: Date
        let weekStart: Date
        let volume: Double
    }

    private func weekSegmentLabel(for session: WorkoutSession) -> String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Older"
        case .concreteWorkout:
            return "Routine"
        case .slotTemplate:
            return "Template"
        }
    }

    private var weeklyWorkoutsByOrigin: [WeekOriginBar] {
        let calendar = Calendar.current
        var tallies: [Date: [String: Int]] = [:]
        for session in filteredSessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let seg = weekSegmentLabel(for: session)
            var m = tallies[weekStart] ?? [:]
            m[seg, default: 0] += 1
            tallies[weekStart] = m
        }
        let segmentOrder = ["Routine", "Template", "Older"]
        return tallies.flatMap { weekStart, counts in
            segmentOrder.compactMap { seg in
                let c = counts[seg] ?? 0
                guard c > 0 else { return nil }
                return WeekOriginBar(
                    id: "\(weekStart.timeIntervalSince1970)-\(seg)",
                    weekStart: weekStart,
                    segment: seg,
                    count: c
                )
            }
        }
        .sorted { a, b in
            if a.weekStart != b.weekStart { return a.weekStart < b.weekStart }
            let oa = segmentOrder.firstIndex(of: a.segment) ?? 99
            let ob = segmentOrder.firstIndex(of: b.segment) ?? 99
            return oa < ob
        }
    }

    private var weeklyVolumeFiltered: [WeekVolumeData] {
        let calendar = Calendar.current
        var volumeByWeek: [Date: Double] = [:]
        for session in filteredSessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let vol = session.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.totalVolumeLoad }
            volumeByWeek[weekStart, default: 0] += vol
        }
        return volumeByWeek
            .map { WeekVolumeData(id: $0.key, weekStart: $0.key, volume: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private var weeklySetCountsFiltered: [WeekData] {
        let calendar = Calendar.current
        var setsByWeek: [Date: Int] = [:]
        for session in filteredSessions {
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
            if filteredSessions.isEmpty {
                Text(sessionsInDateRange.isEmpty ? "No workouts completed in the last \(selectedDays) days" : "No sessions match this source filter")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session).environmentObject(dataVM)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.workout.name)
                                    .font(.headline)
                                Text(formatDate(session.endTime ?? session.startTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sessionOriginCaption(session))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
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
            let grouped = Dictionary(grouping: filteredSessions) { $0.workout.id }
            let sorted = grouped.sorted { ($1.value.first?.endTime ?? .distantPast) > ($0.value.first?.endTime ?? .distantPast) }
            if sorted.isEmpty {
                Text("No workout data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted, id: \.key) { workoutId, sessions in
                    let name = sessions.first?.workout.name ?? "Unknown"
                    let last = sessions.map(\.endTime).compactMap { $0 }.max()
                    NavigationLink(destination: WorkoutHistoryDetailView(sessions: sessions, workoutName: name).environmentObject(dataVM)) {
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
            let stats = exerciseStats(in: filteredSessions)
            if stats.isEmpty {
                Text("No exercise data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.id) { stat in
                    NavigationLink(destination: ExerciseHistoryDetailView(exerciseId: stat.id, sessions: filteredSessions).environmentObject(dataVM)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataVM.resolvedDisplayName(for: stat.sampleExercise))
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
            let stats = muscleGroupStats(in: filteredSessions)
            if stats.isEmpty {
                Text("No muscle group data in this range")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.name) { stat in
                    NavigationLink(destination: MuscleGroupHistoryDetailView(muscleGroupName: stat.name, sessions: filteredSessions).environmentObject(dataVM)) {
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

    private func sessionOriginCaption(_ session: WorkoutSession) -> String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Older session"
        case .concreteWorkout:
            return "Saved workout"
        case .slotTemplate:
            return "Flexible template"
        }
    }
    
    private struct ExerciseStat: Identifiable {
        let id: UUID
        let sampleExercise: Exercise
        let sessions: Int
        let totalSets: Int
        let volume: Double
    }
    
    private func exerciseStats(in sessions: [WorkoutSession]) -> [ExerciseStat] {
        var byId: [UUID: (sample: Exercise, sessions: Set<UUID>, sets: Int, volume: Double)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
                var entry = byId[ex.id] ?? (sample: ex, sessions: [], sets: 0, volume: 0)
                entry.sessions.insert(session.id)
                entry.sets += log.loggedSets.count
                entry.volume += log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                byId[ex.id] = entry
            }
        }
        return byId.map { id, data in
            ExerciseStat(id: id, sampleExercise: data.sample, sessions: data.sessions.count, totalSets: data.sets, volume: data.volume)
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
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
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
}

// MARK: - Session detail (single workout session: exercises + logged sets)
private struct SessionDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    let session: WorkoutSession

    private var endDate: Date { session.endTime ?? session.startTime }

    private var sessionPlanLine: String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Not recorded (older log)"
        case .concreteWorkout:
            return "Saved workout"
        case .slotTemplate(let id):
            let name = dataVM.slotTemplate(id: id)?.name
            return name.map { "Template: \($0)" } ?? "Flexible template"
        }
    }

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
                HStack {
                    Text("Session plan")
                    Spacer()
                    Text(sessionPlanLine)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            ForEach(session.exerciseLogs) { log in
                Section {
                    ForEach(log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(set.weightRepsDisplaySummary())
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
                            let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataVM.displayName(for: log.workoutExercise))
                        if let slotLabel = HistoryView.templateSlotCaption(for: log, session: session, dataVM: dataVM) {
                            Text("Slot: \(slotLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
    @EnvironmentObject var dataVM: DataManager
    let sessions: [WorkoutSession]
    let workoutName: String

    private var sortedSessions: [WorkoutSession] {
        sessions.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    var body: some View {
        List(sortedSessions) { session in
            NavigationLink(destination: SessionDetailView(session: session).environmentObject(dataVM)) {
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
    @EnvironmentObject var dataVM: DataManager
    let exerciseId: UUID
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, log: ExerciseLog)] {
        sessions.compactMap { session in
            guard let log = session.exerciseLogs.first(where: { $0.workoutExercise.exerciseId == exerciseId }) else { return nil }
            return (session, log)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    private var navigationTitle: String {
        if let ex = dataVM.globalExercises.first(where: { $0.id == exerciseId }) {
            return dataVM.resolvedDisplayName(for: ex)
        }
        if let log = sessionLogs.first?.log {
            return dataVM.displayName(for: log.workoutExercise)
        }
        return "Exercise"
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
                    if let slotLabel = HistoryView.templateSlotCaption(for: item.log, session: item.session, dataVM: dataVM) {
                        HStack {
                            Text("Template slot")
                            Spacer()
                            Text(slotLabel)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    ForEach(item.log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(set.weightRepsDisplaySummary())
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
                            let summary = set.configurationSummary(fieldNames: item.log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Muscle group history (sessions + exercises that targeted this muscle + sets)
private struct MuscleGroupHistoryDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    let muscleGroupName: String
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, logs: [ExerciseLog])] {
        sessions.compactMap { session in
            let logs = session.exerciseLogs.filter { log in
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { return false }
                return ex.targetedMuscles.contains(where: { $0.rawValue == muscleGroupName })
                    || (ex.targetedMuscles.isEmpty && muscleGroupName == MuscleGroup.other.rawValue)
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
                        DisclosureGroup {
                            ForEach(log.loggedSets) { set in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(set.weightRepsDisplaySummary())
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
                                    let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                                    if !summary.isEmpty {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dataVM.displayName(for: log.workoutExercise))
                                if let slotLabel = HistoryView.templateSlotCaption(for: log, session: item.session, dataVM: dataVM) {
                                    Text("Slot: \(slotLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
    /// Template slot label for this log when the session was started from a slot template and bindings exist.
    static func templateSlotCaption(for log: ExerciseLog, session: WorkoutSession, dataVM: DataManager) -> String? {
        guard case .slotTemplate(let templateId) = session.sessionPlanOrigin,
              let slotUUID = session.workout.templateSlotId(forWorkoutExerciseRow: log.workoutExercise.id),
              let template = dataVM.slotTemplate(id: templateId),
              let slot = template.slots.first(where: { $0.id == slotUUID })
        else { return nil }
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

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
