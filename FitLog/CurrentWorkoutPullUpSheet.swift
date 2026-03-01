//
//  CurrentWorkoutPullUpSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var selectedExerciseIndex: Int? = nil
    @State private var showLogSetSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Rest Timer Card
                if currentVM.remainingRestTime > 0 {
                    VStack(spacing: 12) {
                        Text("Rest Time Remaining")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(currentVM.remainingRestTime)s")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        
                        Button("Cancel Rest") {
                            currentVM.cancelRestTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // Workout name
                if let session = currentVM.currentSession {
                    Text(session.workout.name)
                        .font(.title2.bold())
                        .padding(.top, currentVM.remainingRestTime > 0 ? 0 : 16)
                        .padding(.horizontal)
                }
                
                // Exercise list with collapsible set details
                List {
                    if let exerciseLogs = currentVM.currentSession?.exerciseLogs, !exerciseLogs.isEmpty {
                        ForEach(exerciseLogs.indices, id: \.self) { index in
                            let log = exerciseLogs[index]
                            
                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedExerciseIndex == index },
                                set: { expandedExerciseIndex = $0 ? index : nil }
                            )) {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Add new set button
                                    Button("Add New Set") {
                                        selectedExerciseIndex = index
                                        showLogSetSheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    // List of logged sets with details
                                    if log.loggedSets.isEmpty {
                                        Text("No sets logged yet")
                                            .foregroundStyle(.secondary)
                                            .italic()
                                            .padding(.vertical, 8)
                                    } else {
                                        ForEach(log.loggedSets.indices, id: \.self) { setIndex in
                                            let set = log.loggedSets[setIndex]
                                            HStack {
                                                Text("\(set.weight, specifier: "%.1f") lbs × \(set.reps)")
                                                    .font(.body)
                                                Spacer()
                                                Text("Rest: \(set.restTime)s")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(10)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .swipeActions {
                                                Button("Delete", role: .destructive) {
                                                    currentVM.deleteSet(exerciseIndex: index, setIndex: setIndex)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(log.workoutExercise.exercise.name)
                                            .font(.headline)
                                        Text("Rec: \(log.workoutExercise.recommendedSets) × \(log.workoutExercise.recommendedReps)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(log.loggedSets.count) sets")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("No exercises in current session")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Current Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        currentVM.stopWorkout()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
                }
            }
            // Open LogSetView when adding a set
            .sheet(isPresented: $showLogSetSheet) {
                if let idx = selectedExerciseIndex {
                    LogSetView(exerciseIndex: idx)
                        .environmentObject(currentVM)
                }
            }
        }
    }
}
