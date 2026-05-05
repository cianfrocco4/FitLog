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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty {
                    List {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { _, log in
                            HStack(spacing: 10) {
                                if log.workoutExercise.isSlotPlaceholder {
                                    Image(systemName: "square.dashed")
                                        .foregroundStyle(.orange)
                                }
                                Text(dataVM.displayName(for: log.workoutExercise))
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("\(log.loggedSets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
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
}
