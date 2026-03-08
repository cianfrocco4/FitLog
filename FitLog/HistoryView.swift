//
//  HistoryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI

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
    
    // MARK: - Workouts completed in last N days
    private var workoutsCompletedSection: some View {
        Section {
            if sessionsInRange.isEmpty {
                Text("No workouts completed in the last \(selectedDays) days")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionsInRange) { session in
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
                        var e = byGroup[m] ?? (sessions: [], exercises: [])
                        e.sessions.insert(session.id)
                        e.exercises.insert(log.workoutExercise.exercise.id)
                        byGroup[m] = e
                    }
                }
            }
        }
        return byGroup.map { name, data in
            MuscleGroupStat(name: name, sessions: data.sessions.count, exerciseCount: data.exercises.count)
        }
    }
}
