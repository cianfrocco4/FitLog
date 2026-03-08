//
//  LogSetView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct LogSetView: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    
    let exerciseIndex: Int
    
    @State private var weight: Double = 0.0
    @State private var reps: Int = 0
    @State private var restTime: Int = 90
    @State private var isWarmup: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Log Set") {
                    Stepper(
                        "Weight: \(weight, specifier: "%.1f") lbs",
                        value: $weight,
                        in: 0...1100,
                        step: 5
                    )
                    
                    Stepper(
                        "Reps: \(reps)",
                        value: $reps,
                        in: 0...50,
                        step: 1
                    )
                    
                    Stepper(
                        "Rest after set: \(restTime)s",
                        value: $restTime,
                        in: 0...300,
                        step: 15
                    )
                    
                    Toggle("Mark as warm-up set", isOn: $isWarmup)
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                prefillFromRecentSet()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        currentVM.logSet(
                            exerciseIndex: exerciseIndex,
                            weight: weight,
                            reps: reps,
                            restTime: restTime,
                            isWarmup: isWarmup
                        )
                        
                        // Small delay for UI updates before dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(weight <= 0 || reps <= 0)
                }
            }
        }
    }

    private func prefillFromRecentSet() {
        guard
            let session = currentVM.currentSession,
            exerciseIndex < session.exerciseLogs.count
        else { return }

        let currentLog = session.exerciseLogs[exerciseIndex]

        // Prefer the most recent set from the current session for this exercise.
        if let lastInSession = currentLog.loggedSets.last {
            weight = lastInSession.weight
            reps = lastInSession.reps
            restTime = lastInSession.restTime
            return
        }

        // Otherwise, look through *all* completed sessions for this exercise,
        // reading from the same UserDefaults key that stopWorkout() uses.
        let targetExerciseId = currentLog.workoutExercise.exercise.id
        var latestSet: LoggedSet?
        
        if let data = UserDefaults.standard.data(forKey: "completedSessions"),
           let allSessions = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            for pastSession in allSessions {
                for log in pastSession.exerciseLogs where log.workoutExercise.exercise.id == targetExerciseId {
                    for set in log.loggedSets {
                        if let existing = latestSet {
                            if set.timestamp > existing.timestamp {
                                latestSet = set
                            }
                        } else {
                            latestSet = set
                        }
                    }
                }
            }
        }

        if let recent = latestSet {
            weight = recent.weight
            reps = recent.reps
            restTime = recent.restTime
            isWarmup = recent.isWarmup
        } else {
            // Fall back to the exercise's default rest time if nothing is logged yet.
            restTime = currentLog.workoutExercise.defaultRestTime
        }
    }
}
