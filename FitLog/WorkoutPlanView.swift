//
//  WorkoutPlanView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct WorkoutPlanView: View {
    @State var workout: Workout
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    
    @State private var showLogSheet = false
    @State private var selectedIndex: Int?
    @State private var showAddExercise = false
    @State private var showRenameAlert = false
    @State private var newWorkoutName = ""
    
    var body: some View {
        List {
            exerciseListSection
            addExerciseButton
        }
        .navigationTitle(workout.name)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showLogSheet) {
            if let idx = selectedIndex {
                LogSetView(workout: workout, exerciseIndex: idx)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            addExerciseSheetContent
        }
        .alert("Rename Workout", isPresented: $showRenameAlert) {
            TextField("New name", text: $newWorkoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                dataVM.renameWorkout(workout, newName: newWorkoutName)
                workout.name = newWorkoutName
            }
        }
    }
    
    // ────────────────────────────────────────────────
    // Extracted sections – this helps the type checker a lot
    // ────────────────────────────────────────────────
    
    private var exerciseListSection: some View {
        ForEach(workout.exercises) { we in
            Button {
                if currentVM.currentSession?.workout.id == workout.id {
                    if let idx = workout.exercises.firstIndex(where: { $0.id == we.id }) {
                        selectedIndex = idx
                        showLogSheet = true
                    }
                }
            } label: {
                HStack {
                    Text(we.exercise.name)
                        .font(.headline)
                    Spacer()
                }
            }
        }
        .onDelete { indexSet in
            indexSet.forEach { i in
                let exerciseId = workout.exercises[i].id
                dataVM.deleteExercise(from: workout, exerciseId: exerciseId)
                workout.exercises.remove(at: i)
            }
        }
    }
    
    private var addExerciseButton: some View {
        Button("Add Exercise from Library") {
            showAddExercise = true
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    newWorkoutName = workout.name
                    showRenameAlert = true
                }
            }
            
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
        }
    }
    
    private var addExerciseSheetContent: some View {
        List(dataVM.globalExercises) { ex in
            Button(ex.name) {
                dataVM.addExercise(to: workout, exercise: ex)
                showAddExercise = false
            }
        }
    }
}
