//
//  NewExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

struct NewExerciseSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss

    /// When set (e.g. from Add Exercise to workout), called with the new exercise after save.
    var onCreated: ((Exercise) -> Void)?

    init(onCreated: ((Exercise) -> Void)? = nil) {
        self.onCreated = onCreated
    }

    @State private var name = ""
    @State private var description = ""
    @State private var selectedMuscles: [MuscleGroup] = []
    @State private var showMusclePicker = false

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
            }
            .navigationTitle("Add New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let created = dataVM.addNewExercise(name: name, description: description, muscles: selectedMuscles)
                        onCreated?(created)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .keyboardDismissToolbar()
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
        }
    }
}
