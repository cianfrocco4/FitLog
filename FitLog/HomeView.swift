//
//  HomeView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @State private var showNewWorkout = false
    @State private var newName = ""
    @State private var workoutToRename: Workout?
    @State private var renameText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Week summary (unchanged)
                    VStack {
                        Text("This Week").font(.title2.bold())
                        Text("\(dataVM.workoutsThisWeek) workouts completed")
                            .font(.system(size: 48, weight: .bold)).foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    VStack(alignment: .leading) {
                        Text("My Workouts").font(.title2.bold())
                        List {
                            ForEach(dataVM.userWorkouts) { workout in
                                NavigationLink(destination: WorkoutPlanView(workout: workout)) {
                                    Text(workout.name)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        dataVM.deleteWorkout(workout)
                                    }
                                    Button("Rename") {
                                        workoutToRename = workout
                                        renameText = workout.name
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar { Button("New Workout") { showNewWorkout = true } }
            .sheet(isPresented: $showNewWorkout) { /* same new workout sheet as before */ }
            .alert("Rename Workout", isPresented: Binding(get: { workoutToRename != nil }, set: { if !$0 { workoutToRename = nil } })) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let workout = workoutToRename {
                        dataVM.renameWorkout(workout, newName: renameText)
                    }
                }
            }
        }
    }
}
