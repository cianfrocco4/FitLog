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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack {
                        Text("This Week").font(.title2.bold())
                        Text("\(dataVM.workoutsThisWeek) workouts completed").font(.system(size: 48, weight: .bold)).foregroundStyle(.blue)
                    }.frame(maxWidth: .infinity).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    VStack(alignment: .leading) {
                        HStack { Text("My Workouts").font(.title2.bold()); Spacer(); Button("New") { showNewWorkout = true } }
                        ForEach(dataVM.userWorkouts) { workout in
                            NavigationLink(destination: WorkoutPlanView(workout: workout)) {
                                HStack { Text(workout.name).font(.headline); Spacer(); Text("\(workout.exercises.count) exercises").font(.subheadline).foregroundStyle(.secondary) }
                                .padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }.padding(.horizontal)
                }
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showNewWorkout) {
                VStack {
                    TextField("Workout Name", text: $newName).textFieldStyle(.roundedBorder).padding()
                    Button("Create") {
                        dataVM.createWorkout(name: newName)
                        newName = ""
                        showNewWorkout = false
                    }.buttonStyle(.borderedProminent)
                }.padding()
            }
        }
    }
}
