//
//  NewWorkoutSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

struct NewWorkoutSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) var dismiss

    @State private var workoutName = ""
    @State private var createdWorkoutId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let id = createdWorkoutId, let binding = $dataVM.userWorkouts[id] {
                    WorkoutPlanView(workout: binding, creationFlowOnDone: { dismiss() })
                        .environmentObject(dataVM)
                        .environmentObject(currentVM)
                        .environmentObject(aiService)
                } else {
                    nameEntryForm
                }
            }
        }
    }

    private var nameEntryForm: some View {
        Form {
            Section(header: Text("Workout Details")) {
                TextField("Workout Name (e.g. Push Day, Legs)", text: $workoutName)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .navigationTitle("Create New Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    createdWorkoutId = dataVM.createWorkout(name: trimmed)
                }
                .disabled(workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .keyboardDismissToolbar()
    }
}
