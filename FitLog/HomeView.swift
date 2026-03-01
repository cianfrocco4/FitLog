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
            VStack(spacing: 0) {
                WeekSummaryView(completedWorkouts: dataVM.workoutsThisWeek)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Text("My Workouts")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                List {
                    ForEach(dataVM.userWorkouts) { workout in
                        NavigationLink {
                            if let binding = $dataVM.userWorkouts[workout.id] {
                                WorkoutPlanView(workout: binding)
                            } else {
                                Text("Workout not found")  // fallback (should never hit)
                                    .foregroundStyle(.red)
                            }
                        } label: {
                            Text(workout.name)
                                .font(.headline)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                dataVM.deleteWorkout(workout)
                            }
                            
                            Button("Rename") {
                                workoutToRename = workout
                                renameText = workout.name
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Workout") {
                        showNewWorkout = true
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
