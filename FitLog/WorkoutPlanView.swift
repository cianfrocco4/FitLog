//
//  WorkoutPlanView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct WorkoutPlanView: View {
    let workout: Workout
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @State private var showLogSheet = false
    @State private var selectedIndex: Int?
    @State private var showAddExercise = false
    
    var body: some View {
        List {
            ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, we in
                Button {
                    if currentVM.currentSession?.workout.id == workout.id {
                        selectedIndex = index
                        showLogSheet = true
                    }
                } label: { HStack { Text(we.exercise.name).font(.headline); Spacer() } }
            }
            .onDelete { indexSet in indexSet.forEach { dataVM.deleteExercise(from: workout, exerciseId: workout.exercises[$0].id) } }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(currentVM.currentSession?.workout.id == workout.id ? "Stop" : "Start") {
                    if currentVM.currentSession?.workout.id == workout.id { currentVM.stopWorkout() } else { currentVM.startWorkout(workout) }
                }.buttonStyle(.borderedProminent).tint(currentVM.currentSession?.workout.id == workout.id ? .red : .green)
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Add Exercise") { showAddExercise = true } }
        }
        .sheet(isPresented: $showLogSheet) { if let idx = selectedIndex { LogSetView(workout: workout, exerciseIndex: idx) } }
        .sheet(isPresented: $showAddExercise) {
            List(dataVM.globalExercises) { ex in Button(ex.name) { dataVM.addExercise(to: workout, exercise: ex); showAddExercise = false } }
        }
    }
}
