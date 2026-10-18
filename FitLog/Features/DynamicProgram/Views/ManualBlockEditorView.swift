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
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

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
                    if let lastLoad = resolvedLastLoadCaption {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(FitLogA11yID.manualBlockEditor.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last working set or last cardio duration from a completed session")
                            .accessibilityAddTraits(.isStaticText)
                    }
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
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return CoralLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

// MARK: - Import rotation sheet

struct ImportRotationFromWorkoutSheet: View {
    let workouts: [Workout]
    let onSelect: (Workout) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

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
                            }
                        }
                        .accessibilityLabel("\(w.name), \(w.exercises.count) exercises")
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
}
