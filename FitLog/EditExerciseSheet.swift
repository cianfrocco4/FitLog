//
//  EditExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI

struct EditExerciseSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss

    let exercise: Exercise

    @State private var name: String
    @State private var description: String
    @State private var selectedMuscles: [MuscleGroup]
    @State private var showMusclePicker = false
    @State private var showDeleteConfirmation = false

    init(exercise: Exercise) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _description = State(initialValue: exercise.description)
        _selectedMuscles = State(initialValue: exercise.targetedMuscles)
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
                    .disabled(!isBuiltIn && name.isEmpty)
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
        let updated: Exercise
        if isBuiltIn {
            updated = Exercise(
                id: exercise.id,
                name: exercise.name,
                description: exercise.description,
                targetedMuscles: exercise.targetedMuscles,
                isCustom: false,
                configurationOptions: exercise.configurationOptions
            )
        } else {
            updated = Exercise(
                id: exercise.id,
                name: name,
                description: description,
                targetedMuscles: selectedMuscles,
                isCustom: true,
                configurationOptions: exercise.configurationOptions
            )
        }
        dataVM.updateExercise(updated)
        dismiss()
    }
}
