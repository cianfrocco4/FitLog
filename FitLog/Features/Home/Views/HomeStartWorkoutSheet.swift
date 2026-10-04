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
    let onStartScheduled: () -> Void
    let onStartLibrary: (Workout) -> Void
    let onNewWorkout: () -> Void
    let onNewFromTemplate: () -> Void
    /// Optional last-load captions keyed by library workout id.
    var lastLoadCaptionByWorkoutId: [UUID: String] = [:]
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

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
                                    lastLoadCaptionView(for: scheduled)
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
                                        Text(HomeWorkoutFormatting.lastDoneLabel(for: lastCompletedDates[workout.id]))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        lastLoadCaptionView(for: workout)
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

    @ViewBuilder
    private func lastLoadCaptionView(for workout: Workout) -> some View {
        if let caption = lastLoadCaptionByWorkoutId[workout.id], !caption.isEmpty {
            lastLoadLine(caption)
        } else if resolvesLastLoadFromEnvironment {
            HomeStartSheetLastLoadCaption(workout: workout)
        }
    }

    private func lastLoadLine(_ caption: String) -> some View {
        Text(caption)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(FitLogA11yID.homeStartSheet.lastLoad)
            .accessibilityLabel(caption)
            .accessibilityHint("Last working set or last cardio duration from a completed session")
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct HomeStartSheetLastLoadCaption: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    let workout: Workout

    var body: some View {
        if let lastLoad = JuniperLastWorkingLoad.caption(
            for: workout,
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        ) {
            Text(lastLoad)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(FitLogA11yID.homeStartSheet.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last working set or last cardio duration from a completed session")
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
