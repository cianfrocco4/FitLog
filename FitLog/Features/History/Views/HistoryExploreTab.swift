//
//  HistoryExploreTab.swift
//  FitLog
//

import SwiftUI

struct HistoryExploreTab: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        Group {
            workoutAnalyticsSection
            exerciseAnalyticsSection
            muscleGroupAnalyticsSection
        }
        .onAppear {
            viewModel.ensureExploreData(dataVM: dataVM)
        }
    }

    private var workoutAnalyticsSection: some View {
        Section {
            let grouped = Dictionary(grouping: viewModel.sessionsInDateRange) { $0.workout.id }
            let q = viewModel.exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let sorted = grouped
                .sorted { ($1.value.first?.endTime ?? .distantPast) > ($0.value.first?.endTime ?? .distantPast) }
                .filter { q.isEmpty || ($0.value.first?.workout.name ?? "").lowercased().contains(q) }
            if sorted.isEmpty {
                Text(q.isEmpty ? "No workout data in this range" : "No workouts match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted, id: \.key) { workoutId, sessions in
                    let name = sessions.first?.workout.name ?? "Unknown"
                    let last = sessions.map(\.endTime).compactMap { $0 }.max()
                    NavigationLink(destination: WorkoutHistoryDetailView(workoutId: workoutId, workoutName: name)
                        .environment(dataVM)
                        .environment(currentVM)
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.headline)
                                if let last {
                                    Text("Last: \(HistoryFormatters.formatDateTime(last))")
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

    private var exerciseAnalyticsSection: some View {
        Section {
            let q = viewModel.exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stats = viewModel.exerciseStats.filter {
                q.isEmpty || dataVM.resolvedDisplayName(for: $0.sampleExercise).lowercased().contains(q)
            }
            if stats.isEmpty {
                Text(q.isEmpty ? "No exercise data in this range" : "No exercises match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.id) { stat in
                    NavigationLink(destination: ExerciseHistoryDetailView(
                        exerciseId: stat.id,
                        rangeSessions: viewModel.sessionsInDateRange,
                        allSessionsSorted: viewModel.allSessionsSorted
                    )
                        .environment(dataVM)
                        .environmentObject(userPreferences)
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataVM.resolvedDisplayName(for: stat.sampleExercise))
                                .font(.headline)
                            HStack(spacing: 16) {
                                Label("\(stat.sessions) session\(stat.sessions == 1 ? "" : "s")", systemImage: "calendar")
                                Label("\(stat.totalSets) sets", systemImage: "square.stack.3d.up")
                                if stat.volume > 0 {
                                    Label(
                                        WeightStoreConversion.formatVolumeLbRep(stat.volume, unit: userPreferences.weightDisplayUnit),
                                        systemImage: "scalemass"
                                    )
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

    private var muscleGroupAnalyticsSection: some View {
        Section {
            let q = viewModel.exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stats = viewModel.muscleGroupStats.filter {
                q.isEmpty || $0.name.lowercased().contains(q)
            }
            if stats.isEmpty {
                Text(q.isEmpty ? "No muscle group data in this range" : "No muscle groups match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.name) { stat in
                    NavigationLink(destination: MuscleGroupHistoryDetailView(
                        muscleGroupName: stat.name,
                        sessions: viewModel.sessionsInDateRange
                    )
                        .environment(dataVM)
                        .environmentObject(userPreferences)
                    ) {
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
}
