//
//  EditExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI

struct EditExerciseSheet: View {
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) var dismiss

    let exercise: Exercise

    @State private var name: String
    @State private var description: String
    @State private var selectedMuscles: [MuscleGroup]
    @State private var configurationOptions: [ExerciseConfigurationOption]
    @State private var showMusclePicker = false
    @State private var showDeleteConfirmation = false
    @State private var showExactNameConflict = false

    init(exercise: Exercise) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _description = State(initialValue: exercise.description)
        _selectedMuscles = State(initialValue: exercise.targetedMuscles)
        _configurationOptions = State(initialValue: exercise.configurationOptions)
    }
    
    private var availableMuscles: [MuscleGroup] {
        MuscleGroup.displayOrder.filter { !selectedMuscles.contains($0) }
    }

    private var isBuiltIn: Bool { !exercise.isCustom }

    var body: some View {
        NavigationStack {
            Form {
                exerciseInfoSection
                muscleGroupsSection
                setupOptionsSection
                if exercise.isCustom {
                    deleteSection
                }
            }
            .navigationTitle(isBuiltIn ? "Configuration options" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(!isBuiltIn && (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .keyboardDismissToolbar()
            .sheet(isPresented: $showMusclePicker) {
                musclePickerSheet
            }
            .confirmationDialog("Delete Exercise?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    dataVM.deleteGlobalExercise(exercise)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \"\(exercise.name)\" from the library and from any workouts that include it. This cannot be undone.")
            }
            .alert("Name already used", isPresented: $showExactNameConflict) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Another exercise in your library already uses this name.")
            }
        }
    }

    private var exerciseInfoSection: some View {
        Section("Exercise Info") {
            if isBuiltIn {
                Text(dataVM.resolvedDisplayName(for: exercise))
                    .font(.headline)
                if dataVM.hasLocalDisplayName(for: exercise.id) {
                    Text("Standard name: \(exercise.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(exercise.description)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
            }
        }
    }

    private var muscleGroupsSection: some View {
        Section("Muscle Groups (up to 3, in order of applicability)") {
            if isBuiltIn {
                ForEach(selectedMuscles.indices, id: \.self) { index in
                    Text(selectedMuscles[index].rawValue)
                }
            } else {
                ForEach(selectedMuscles.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(selectedMuscles[index].rawValue)
                        Spacer()
                        Button(role: .destructive) {
                            selectedMuscles.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                    }
                }
                if selectedMuscles.count < 3 {
                    Button {
                        showMusclePicker = true
                    } label: {
                        Label("Add muscle group", systemImage: "plus.circle")
                    }
                }
            }
        }
    }

    private var setupOptionsSection: some View {
        Section {
            ExerciseConfigurationOptionsEditor(options: $configurationOptions)
        } header: {
            Text("Setup options")
        } footer: {
            Text("Record grip, seat, or attachment with each set. Use these for machine variants — a wide, medium, and narrow grip stay one exercise so history and records are not split.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Exercise", systemImage: "trash")
            }
        }
    }

    private var musclePickerSheet: some View {
        NavigationStack {
            List(availableMuscles) { mg in
                Button(mg.rawValue) {
                    selectedMuscles.append(mg)
                    showMusclePicker = false
                }
            }
            .navigationTitle("Muscle Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showMusclePicker = false }
                }
            }
        }
    }

    private func saveAndDismiss() {
        var updated = exercise
        updated.configurationOptions = cleanedConfigurationOptions()
        if !isBuiltIn {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return }
            if dataVM.globalExercises.contains(where: {
                $0.id != exercise.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            }) {
                showExactNameConflict = true
                return
            }
            updated.name = trimmedName
            updated.description = description
            updated.targetedMuscles = selectedMuscles
        }
        dataVM.updateExercise(updated)
        dismiss()
    }

    /// Unnamed options cannot be recorded against a set, so they are dropped on save.
    private func cleanedConfigurationOptions() -> [ExerciseConfigurationOption] {
        configurationOptions.compactMap { option in
            let trimmed = option.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ExerciseConfigurationOption(id: option.id, name: trimmed, choices: option.choices)
        }
    }
}
