//
//  NewExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

private struct ConfigOptionEditRow: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var choicesString: String = ""
}

struct NewExerciseSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedMuscles: [MuscleGroup] = []
    @State private var configRows: [ConfigOptionEditRow] = []
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
                Section {
                    ForEach(configRows.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Option name (e.g. Grip, Seat)", text: $configRows[index].name)
                            TextField("Choices (comma-separated; leave empty for free-form)", text: $configRows[index].choicesString, axis: .vertical)
                                .font(.caption)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    Button {
                        configRows.append(ConfigOptionEditRow())
                    } label: {
                        Label("Add configuration option", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Set options (optional)")
                } footer: {
                    Text("Track variants per set (e.g. grip type, machine settings). Shown when logging a set and in history.")
                }
            }
            .navigationTitle("Add New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let opts = configRows
                            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                            .map { row in
                                let choices = row.choicesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
                                return ExerciseConfigurationOption(id: row.id, name: row.name.trimmingCharacters(in: .whitespaces), choices: choices)
                            }
                        dataVM.addNewExercise(name: name, description: description, muscles: selectedMuscles, configurationOptions: opts)
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
        }
    }
}
