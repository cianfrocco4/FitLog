//
//  WorkoutPlanView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct WorkoutPlanView: View {
    @Binding var workout: Workout
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @State private var showLogSheet = false
    @State private var selectedIndex: Int?
    @State private var showAddExercise = false
    @State private var showRenameAlert = false
    @State private var newWorkoutName = ""
    
    var body: some View {
        List {
            ForEach(workout.exercises.indices, id: \.self) { i in
                let we = workout.exercises[i]
                Button {
                    if currentVM.currentSession?.workout.id == workout.id {
                        selectedIndex = i
                        showLogSheet = true
                    }
                } label: {
                    HStack {
                        Text(we.exercise.name).font(.headline)
                        Spacer()
                        Text("Rec: \(we.recommendedSets) sets x \(we.recommendedReps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { i in
                    dataVM.deleteExercise(from: workout, exerciseId: workout.exercises[i].id)
                }
            }
            
            Button("Add Exercise") { showAddExercise = true }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(currentVM.currentSession?.workout.id == workout.id ? "Stop" : "Start") {
                    if currentVM.currentSession?.workout.id == workout.id {
                        currentVM.stopWorkout()
                    } else {
                        currentVM.startWorkout(workout)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(currentVM.currentSession?.workout.id == workout.id ? .red : .green)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    newWorkoutName = workout.name
                    showRenameAlert = true
                }
            }
        }
        .sheet(isPresented: $showLogSheet) {
            if let idx = selectedIndex {
                LogSetView(exerciseIndex: idx)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(workout: workout)
        }
        .alert("Rename Workout", isPresented: $showRenameAlert) {
            TextField("New name", text: $newWorkoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                dataVM.renameWorkout(workout, newName: newWorkoutName)
            }
        }
    }
}

struct AddExerciseSheet: View {
    let workout: Workout
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedExercise: Exercise?
    @State private var recommendedSets = 3
    @State private var recommendedReps = "8-12"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Exercise") {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(dataVM.globalExercises) { ex in
                            Text(ex.name).tag(ex as Exercise?)
                        }
                    }
                }
                
                Section("Recommended") {
                    Stepper("Sets: \(recommendedSets)", value: $recommendedSets, in: 1...10)
                    TextField("Reps (e.g. 8-12)", text: $recommendedReps)
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let ex = selectedExercise {
                            dataVM.addExercise(to: workout, exercise: ex, recommendedSets: recommendedSets, recommendedReps: recommendedReps)
                            dismiss()
                        }
                    }
                    .disabled(selectedExercise == nil)
                }
            }
        }
    }
}
