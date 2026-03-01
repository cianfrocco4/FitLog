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
    
    @State private var selectedExerciseIndex: Int? = nil
    @State private var showLogSetSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let session = currentVM.currentSession {
                    Text(session.workout.name)
                        .font(.title2.bold())
                        .padding(.top)
                    
                    // Show first exercise (or nothing) - no currentExerciseIndex in v1.0
                    if let firstLog = session.exerciseLogs.first {
                        Text("First exercise: \(firstLog.workoutExercise.exercise.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        Text("No exercises logged yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                
                // ────────────────────────────────────────────────
                // REST TIMER SECTION (only visible when timer is active)
                // ────────────────────────────────────────────────
                if currentVM.remainingRestTime > 0 {
                    VStack(spacing: 12) {
                        Text("Rest Time Remaining")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(currentVM.remainingRestTime)s")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        
                        Button("Cancel Rest") {
                            currentVM.cancelRestTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6).opacity(0.8))
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                List {
                    if let exerciseLogs = currentVM.currentSession?.exerciseLogs {
                        ForEach(Array(exerciseLogs.enumerated()), id: \.offset) { index, log in
                            Button {
                                selectedExerciseIndex = index
                                showLogSetSheet = true
                            } label: {
                                HStack {
                                    Text(log.workoutExercise.exercise.name)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(log.loggedSets.count) sets")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 4)
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
            .sheet(isPresented: $showLogSetSheet) {
                if let idx = selectedExerciseIndex {
                    LogSetView(exerciseIndex: idx)
                        .environmentObject(currentVM)
                }
            }
        }
    }
}
