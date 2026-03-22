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
    /// Field name -> value for this set.
    @State private var configValues: [String: String] = [:]

    private var workoutExercise: WorkoutExercise? {
        guard let session = currentVM.currentSession, exerciseIndex < session.exerciseLogs.count else { return nil }
        return session.exerciseLogs[exerciseIndex].workoutExercise
    }

    private static let weightRange: ClosedRange<Double> = 0...1100

    /// Keeps weight in range for both typing and the stepper (no negatives, no values above max).
    private var clampedWeightBinding: Binding<Double> {
        Binding(
            get: { weight },
            set: { new in
                guard new.isFinite else { return }
                weight = Self.clampWeight(new)
            }
        )
    }

    private static func clampWeight(_ w: Double) -> Double {
        guard w.isFinite else { return 0 }
        return min(weightRange.upperBound, max(weightRange.lowerBound, w))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Log Set") {
                    LabeledContent("Weight") {
                        HStack(spacing: 10) {
                            TextField("0", value: clampedWeightBinding, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 56)
                            Text("lb")
                                .foregroundStyle(.secondary)
                            Stepper("", value: clampedWeightBinding, in: Self.weightRange, step: 5)
                                .labelsHidden()
                                .accessibilityLabel("Adjust weight by 5 pounds")
                        }
                    }
                    if weight == 0 {
                        Text("0 lb = body weight only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
                if let we = workoutExercise, !we.configurationFields.isEmpty {
                    Section("Configuration") {
                        ForEach(we.configurationFields, id: \.self) { field in
                            TextField(field, text: bindingForField(field))
                        }
                    }
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
                            isWarmup: isWarmup,
                            configuration: configValues
                        )

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(reps <= 0)
                }
            }
            .keyboardDismissToolbar()
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
            weight = Self.clampWeight(lastInSession.weight)
            reps = lastInSession.reps
            restTime = lastInSession.restTime
            isWarmup = lastInSession.isWarmup
            if !lastInSession.configuration.isEmpty {
                configValues = lastInSession.configuration
            }
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
            weight = Self.clampWeight(recent.weight)
            reps = recent.reps
            restTime = recent.restTime
            isWarmup = recent.isWarmup
            if !recent.configuration.isEmpty { configValues = recent.configuration }
        } else {
            restTime = currentLog.workoutExercise.defaultRestTime

            // If there are recommended configuration values for this set index, prefill them.
            if !currentLog.workoutExercise.recommendedConfigBySet.isEmpty {
                let nextIndex = currentLog.loggedSets.count
                if nextIndex < currentLog.workoutExercise.recommendedConfigBySet.count {
                    configValues = currentLog.workoutExercise.recommendedConfigBySet[nextIndex]
                }
            }
        }
    }

    private func bindingForField(_ name: String) -> Binding<String> {
        let key = name
        return Binding(
            get: { configValues[key] ?? "" },
            set: { newValue in
                var next = configValues
                next[key] = newValue
                configValues = next
            }
        )
    }
}
