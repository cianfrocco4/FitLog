//
//  ExerciseReorderSheet.swift
//  FitLog
//
//  Modal reorder for active session exercises (flat List + onMove) to avoid
//  SwiftUI reorder bugs inside nested Section layouts in the pull-up sheet.
//

import SwiftUI

struct ExerciseReorderSheet: View {
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss

    private var lastLoadByExerciseId: [UUID: String] {
        CedarLastWorkingLoad.captionsByExerciseId(
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty {
                    List {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { _, log in
                            let lastLoad = log.workoutExercise.exerciseId.flatMap { lastLoadByExerciseId[$0] }
                            HStack(spacing: 10) {
                                if log.workoutExercise.isSlotPlaceholder {
                                    Image(systemName: "square.dashed")
                                        .foregroundStyle(.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dataVM.displayName(for: log.workoutExercise))
                                        .font(.body.weight(.medium))
                                    if let lastLoad {
                                        Text(lastLoad)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier(FitLogA11yID.exerciseReorder.lastLoad)
                                    }
                                }
                                Spacer()
                                Text("\(log.loggedSets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(reorderAccessibilityLabel(for: log, lastLoad: lastLoad))
                        }
                        .onMove(perform: handleMove)
                    }
                    .listStyle(.plain)
                } else {
                    ContentUnavailableView("No exercises", systemImage: "list.bullet")
                }
            }
            .navigationTitle("Reorder exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes the reorder list and keeps the new order.")
                }
            }
        }
    }

    private func handleMove(from source: IndexSet, to destination: Int) {
        let logs = currentVM.currentSession?.exerciseLogs ?? []
        guard !logs.isEmpty else { return }
        let safeSource = IndexSet(source.filter { $0 >= 0 && $0 < logs.count })
        guard !safeSource.isEmpty else { return }
        let safeDestination = min(max(0, destination), logs.count)
        currentVM.moveExerciseLogs(fromOffsets: safeSource, toOffset: safeDestination)
    }

    private func reorderAccessibilityLabel(for log: ExerciseLog, lastLoad: String?) -> String {
        var parts = [dataVM.displayName(for: log.workoutExercise)]
        if let lastLoad { parts.append(lastLoad) }
        let setCount = log.loggedSets.count
        parts.append("\(setCount) \(setCount == 1 ? "set" : "sets")")
        return parts.joined(separator: ", ")
    }
}
