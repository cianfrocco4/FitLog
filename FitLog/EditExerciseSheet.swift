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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                }
                Section("Muscle Groups (up to 3, in order of applicability)") {
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
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let updated = Exercise(
                            id: exercise.id,
                            name: name,
                            description: description,
                            targetedMuscles: selectedMuscles,
                            isCustom: true
                        )
                        dataVM.updateExercise(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showMusclePicker) {
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
}
