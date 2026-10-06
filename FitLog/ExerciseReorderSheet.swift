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
    /// Optional last-load captions keyed by library exercise id.
    var lastLoadCaptionByExerciseId: [UUID: String] = [:]
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dataVM.displayName(for: log.workoutExercise))
                                        .font(.body.weight(.medium))
                                    lastLoadCaptionView(for: log)
                                }
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

    @ViewBuilder
    private func lastLoadCaptionView(for log: ExerciseLog) -> some View {
        if let id = log.workoutExercise.exerciseId,
           let caption = lastLoadCaptionByExerciseId[id],
           !caption.isEmpty {
            lastLoadLine(caption)
        } else if resolvesLastLoadFromEnvironment {
            ExerciseReorderLastLoadCaption(
                workoutExercise: log.workoutExercise,
                excludingSessionId: currentVM.currentSession?.id
            )
        }
    }

    private func lastLoadLine(_ caption: String) -> some View {
        Text(caption)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(FitLogA11yID.exerciseReorder.lastLoad)
            .accessibilityLabel(caption)
            .accessibilityHint("Last working set or last cardio duration from a completed session")
            .accessibilityAddTraits(.isStaticText)
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

private struct ExerciseReorderLastLoadCaption: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    let workoutExercise: WorkoutExercise
    let excludingSessionId: UUID?

    var body: some View {
        if let lastLoad = WalnutLastWorkingLoad.caption(
            for: workoutExercise,
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit,
            excludingSessionId: excludingSessionId
        ) {
            Text(lastLoad)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(FitLogA11yID.exerciseReorder.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last working set or last cardio duration from a completed session")
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
