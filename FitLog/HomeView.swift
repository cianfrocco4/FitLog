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
    @State private var workoutToRename: Workout?
    @State private var renameText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    WeekSummaryView(completedWorkouts: dataVM.workoutsThisWeek)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Workouts")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                    
                        Text("Workouts count: \(dataVM.userWorkouts.count)")
                            .foregroundStyle(.purple)
                            .padding()
                    
                        if dataVM.userWorkouts.isEmpty {
                            Text("No workouts yet. Create one to get started!")
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Should show \(dataVM.userWorkouts.count) items")
                                .foregroundStyle(.green)
                                .padding()
                            
                            // TODO:
                            List {
                                ForEach(dataVM.userWorkouts.indices, id: \.self) { index in
                                    let workout = dataVM.userWorkouts[index]
                                    Text("→ \(workout.name) (index \(index))")
                                        .font(.headline)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                }
                            }
                            .listStyle(.plain)
                            
                            // TODO:
//                            List {
//                                ForEach(dataVM.userWorkouts) { workout in
//                                    Text("→ \(workout.name)")
//                                        .font(.headline)
//                                        .padding()
//                                        .background(Color.blue.opacity(0.1))
//                                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                                }
//                            }
//                            .listStyle(.plain)
                            
                            // TODO: Original
//                            List {
//                                ForEach(dataVM.userWorkouts) { workout in
//                                    NavigationLink(destination: WorkoutPlanView(workout: workout)) {
//                                        Text(workout.name)
//                                            .font(.headline)
//                                    }
//                                    .swipeActions(edge: .trailing) {
//                                        Button("Delete", role: .destructive) {
//                                            dataVM.deleteWorkout(workout)
//                                        }
//                                        
//                                        Button("Rename") {
//                                            workoutToRename = workout
//                                            renameText = workout.name
//                                        }
//                                        .tint(.blue)
//                                    }
//                                }
//                            }
//                            .listStyle(.plain)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showNewWorkout = true
                    }) {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewWorkout) {
                NewWorkoutSheet()
                    .environmentObject(dataVM)
            }
            .alert("Rename Workout", isPresented: Binding(
                get: { workoutToRename != nil },
                set: { if !$0 { workoutToRename = nil } }
            )) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let workout = workoutToRename {
                        dataVM.renameWorkout(workout, newName: renameText)
                    }
                }
            } message: {
                Text("Enter a new name for this workout")
            }
        }
    }
}
