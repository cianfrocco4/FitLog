//
//  LocalExerciseRenameSheet.swift
//  FitLog
//
//  Optional display name for any library exercise (built-in or custom), local to this device.
//

import SwiftUI

struct LocalExerciseRenameSheet: View {
    let exercise: Exercise
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) var dismiss

    @State private var editedName: String
    @FocusState private var nameFocused: Bool

    init(exercise: Exercise, initialDisplayName: String) {
        self.exercise = exercise
        _editedName = State(initialValue: initialDisplayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $editedName)
                        .focused($nameFocused)
                    if let lastLoad = resolvedLastLoadCaption {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(FitLogA11yID.localExerciseRename.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last working set or last cardio duration for this exercise")
                            .accessibilityAddTraits(.isStaticText)
                    }
                    Text("Only you see this name. The standard exercise entry in the library stays the same.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Standard name") {
                    Text(exercise.name)
                        .foregroundStyle(.secondary)
                }
                if dataVM.hasLocalDisplayName(for: exercise.id) {
                    Section {
                        Button("Use standard name", role: .none) {
                            dataVM.clearLocalExerciseDisplayName(for: exercise.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Rename locally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataVM.setLocalExerciseDisplayName(for: exercise.id, customName: editedName)
                        dismiss()
                    }
                }
            }
            .keyboardDismissToolbar()
            .onAppear { nameFocused = true }
        }
    }

    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return TeakLastWorkingLoad.caption(
            for: exercise.id,
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}
