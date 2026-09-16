//
//  ManualBlockEditorView.swift
//  FitLog
//
//  Manual-mode toolbar and import flows layered above template editing.
//

import SwiftUI

struct ManualBlockEditorView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @State private var showImportRotationSheet = false

    var body: some View {
        Group {
            if viewModel.generatedProgram != nil {
                Section {
                    HStack {
                        BlockOperationsMenu(
                            viewModel: viewModel,
                            exerciseLibrary: dataManager.globalExercises,
                            showImportRotationSheet: $showImportRotationSheet
                        )
                        Spacer()
                    }
                    Text("Duplicate blocks, reuse a previous phase’s rotation, or pull exercises from a saved workout template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Manual tools")
                }
            }
        }
        .sheet(isPresented: $showImportRotationSheet) {
            ImportRotationFromWorkoutSheet(
                workouts: dataManager.userWorkouts,
                onSelect: { workout in
                    viewModel.importRotationFromWorkout(
                        workout,
                        blockIndex: viewModel.editableBlockIndex,
                        exerciseLibrary: dataManager.globalExercises
                    )
                    showImportRotationSheet = false
                },
                onCancel: { showImportRotationSheet = false }
            )
            .environment(dataManager)
            .environmentObject(userPreferences)
        }
    }
}

// MARK: - Import rotation sheet

struct ImportRotationFromWorkoutSheet: View {
    let workouts: [Workout]
    let onSelect: (Workout) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @State private var query = ""

    private var lastLoadByWorkoutId: [UUID: String] {
        let sessions = dataManager.completedSessions
        let unit = userPreferences.weightDisplayUnit
        var result: [UUID: String] = [:]
        for workout in workouts {
            if let caption = WillowLastWorkingLoad.caption(
                forWorkout: workout,
                from: sessions,
                displayUnit: unit
            ) {
                result[workout.id] = caption
            }
        }
        return result
    }

    private var filtered: [Workout] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return workouts }
        return workouts.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts",
                        systemImage: "tray",
                        description: Text("Create a workout in your library first, then import its exercise list here.")
                    )
                } else {
                    ForEach(filtered) { w in
                        let lastLoad = lastLoadByWorkoutId[w.id]
                        Button {
                            onSelect(w)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(w.name)
                                    .font(.body.weight(.medium))
                                Text("\(w.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let lastLoad {
                                    Text(lastLoad)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier(FitLogA11yID.importRotation.lastLoad)
                                }
                            }
                        }
                        .accessibilityLabel(importRotationAccessibilityLabel(for: w, lastLoad: lastLoad))
                        .accessibilityHint("Replaces the current block’s rotation with this workout’s exercises.")
                    }
                }
            }
            .navigationTitle("Import rotation")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .accessibilityHint("Dismisses without importing.")
                }
            }
        }
    }

    private func importRotationAccessibilityLabel(for workout: Workout, lastLoad: String?) -> String {
        var parts = [workout.name, "\(workout.exercises.count) exercises"]
        if let lastLoad { parts.append(lastLoad) }
        return parts.joined(separator: ", ")
    }
}
