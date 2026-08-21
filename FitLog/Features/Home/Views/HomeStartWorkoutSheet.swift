//
//  HomeStartWorkoutSheet.swift
//  FitLog
//
//  Quick-pick sheet for the Home start-workout FAB.
//

import SwiftUI

struct HomeStartWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) var dataVM

    let todayPlan: ResolvedScheduleDay
    let scheduledWorkout: Workout?
    let recentWorkouts: [Workout]
    let lastCompletedDates: [UUID: Date]
    var lastDurations: [UUID: Int] = [:]
    let onStartScheduled: () -> Void
    let onStartLibrary: (Workout) -> Void
    let onNewWorkout: () -> Void
    let onNewFromTemplate: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if case .workout = todayPlan, let scheduled = scheduledWorkout {
                    Section {
                        Button(action: {
                            dismiss()
                            onStartScheduled()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "sun.max.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today's plan")
                                        .font(.headline)
                                    Text(scheduled.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityHint("Starts today's scheduled workout")
                    } header: {
                        Text("Recommended")
                    }
                }

                if !recentWorkouts.isEmpty {
                    Section {
                        ForEach(recentWorkouts) { workout in
                            Button {
                                dismiss()
                                onStartLibrary(workout)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: workout.workoutKind.homeSystemImage)
                                        .foregroundStyle(workout.workoutKind.homeAccentColor)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(workout.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(
                                            HomeWorkoutFormatting.lastDoneWithDurationLabel(
                                                date: lastCompletedDates[workout.id],
                                                durationSeconds: lastDurations[workout.id]
                                            )
                                        )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Recent")
                    }
                }

                Section {
                    if recentWorkouts.isEmpty, scheduledWorkout == nil {
                        Text("Create a workout first, then you can start it from here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        dismiss()
                        onNewWorkout()
                    } label: {
                        Label("New workout", systemImage: "plus.rectangle.on.folder")
                    }
                    .accessibilityHint("Opens the new workout form")
                    .accessibilityIdentifier(FitLogA11yID.newWorkout)
                    Button {
                        dismiss()
                        onNewFromTemplate()
                    } label: {
                        Label("From template", systemImage: "square.grid.2x2")
                    }
                    .accessibilityHint("Opens quick-start workout templates")
                    .accessibilityIdentifier(FitLogA11yID.fromTemplate)
                } header: {
                    Text(recentWorkouts.isEmpty && scheduledWorkout == nil ? "Get started" : "Create")
                }
            }
            .navigationTitle("Start workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
