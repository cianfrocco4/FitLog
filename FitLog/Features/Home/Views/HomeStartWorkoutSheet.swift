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
    @EnvironmentObject var userPreferences: UserPreferences

    let todayPlan: ResolvedScheduleDay
    let scheduledWorkout: Workout?
    let recentWorkouts: [Workout]
    let lastCompletedDates: [UUID: Date]
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
                                    if let recap = lastWorkingLine(for: scheduled.id) {
                                        Text(recap)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .accessibilityHint("Starts today's scheduled workout")
                        .accessibilityLabel(todayPlanAccessibilityLabel(scheduled))
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
                                        Text(HomeWorkoutFormatting.lastDoneLabel(for: lastCompletedDates[workout.id]))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let recap = lastWorkingLine(for: workout.id) {
                                            Text(recap)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                            .accessibilityLabel(recentWorkoutAccessibilityLabel(workout))
                            .accessibilityHint("Starts this workout as a new session")
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

    private func lastWorkingLine(for libraryId: UUID) -> String? {
        guard let session = dataVM.lastCompletedSession(forLibraryWorkoutId: libraryId) else { return nil }
        return LastSessionWorkingRecap.compactLine(from: session, weightUnit: userPreferences.weightDisplayUnit)
    }

    private func todayPlanAccessibilityLabel(_ scheduled: Workout) -> String {
        var parts = ["Today's plan", scheduled.name]
        if let recap = lastWorkingLine(for: scheduled.id) {
            parts.append(recap)
        }
        return parts.joined(separator: ", ")
    }

    private func recentWorkoutAccessibilityLabel(_ workout: Workout) -> String {
        var parts = [
            workout.name,
            HomeWorkoutFormatting.lastDoneLabel(for: lastCompletedDates[workout.id])
        ]
        if let recap = lastWorkingLine(for: workout.id) {
            parts.append(recap)
        }
        return parts.joined(separator: ", ")
    }
}
