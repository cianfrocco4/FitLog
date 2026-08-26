//
//  HomeActiveWorkoutCard.swift
//  FitLog
//
//  Enriched in-progress workout card with progress and quick actions.
//

import SwiftUI

struct HomeActiveWorkoutCard: View {
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM

    let onOpen: () -> Void
    let onFinish: () -> Void

    @State private var pulsePhase = false
    @State private var pauseResumeHapticTick = 0

    private var session: WorkoutSession? { currentVM.currentSession }

    private var completedExerciseCount: Int {
        HomeActiveWorkoutProgress.completedExerciseCount(in: session?.exerciseLogs ?? [])
    }

    private var totalExerciseCount: Int {
        HomeActiveWorkoutProgress.countableExerciseCount(in: session?.exerciseLogs ?? [])
    }

    private var progressFraction: Double {
        HomeActiveWorkoutProgress.progressFraction(
            completed: completedExerciseCount,
            total: totalExerciseCount
        )
    }

    private var currentExerciseName: String {
        guard let session,
              let primaryId = currentVM.primaryActiveExerciseId,
              let log = session.exerciseLogs.first(where: { $0.workoutExercise.exerciseId == primaryId })
        else { return "Getting started" }
        return dataVM.displayName(for: log.workoutExercise)
    }

    private var loggedSetCount: Int {
        session?.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count } ?? 0
    }

    private var shouldShowLoggingHint: Bool {
        loggedSetCount == 0
    }

    private var restRemainingSeconds: Int {
        currentVM.remainingRestTime
    }

    private var nextUpSubtitle: String? {
        WorkoutRestTimerBarCopy.namedSubtitle(for: currentVM.nextUpTarget())
    }

    private var activeWorkoutOpenAccessibilityLabel: String {
        var parts = ["Workout in progress"]
        if let name = session?.workout.name, !name.isEmpty {
            parts.append(name)
        }
        parts.append("Now \(currentExerciseName)")
        parts.append(currentVM.workoutElapsedFormatted)
        if currentVM.isWorkoutPaused {
            parts.append("Paused")
        }
        if restRemainingSeconds > 0 {
            parts.append(WorkoutRestTimerBarCopy.restCountdownLabel(seconds: restRemainingSeconds))
            if let nextUpSubtitle {
                parts.append(nextUpSubtitle)
            }
        }
        if totalExerciseCount > 0 {
            parts.append("\(completedExerciseCount) of \(totalExerciseCount) exercises")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(FitlogPalette.success.opacity(pulsePhase ? 0.35 : 0.15))
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill(FitlogPalette.success)
                            .frame(width: 10, height: 10)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout in progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(session?.workout.name ?? "")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Now: \(currentExerciseName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(currentVM.workoutElapsedFormatted)
                                .font(.subheadline.weight(.medium).monospacedDigit())
                            if restRemainingSeconds > 0 {
                                Text(WorkoutRestTimerBarCopy.restCountdownLabel(seconds: restRemainingSeconds))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(FitlogPalette.caution)
                                    .accessibilityHidden(true)
                            }
                            if currentVM.isWorkoutPaused {
                                Text("Paused")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(FitlogPalette.caution)
                            }
                            if totalExerciseCount > 0 {
                                Text("· \(completedExerciseCount)/\(totalExerciseCount) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeWorkoutOpenAccessibilityLabel)
            .accessibilityHint("Opens exercise logging for the current workout")

            if totalExerciseCount > 0 {
                ProgressView(value: progressFraction)
                    .tint(FitlogPalette.success)
                    .accessibilityLabel("Exercise progress, \(completedExerciseCount) of \(totalExerciseCount)")
            }

            if shouldShowLoggingHint {
                Text("Tap Log Sets to record your exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 10) {
                Button {
                    if currentVM.isWorkoutPaused {
                        currentVM.resumeWorkout()
                    } else {
                        currentVM.pauseWorkout()
                    }
                    pauseResumeHapticTick += 1
                } label: {
                    Label(
                        currentVM.isWorkoutPaused ? "Resume" : "Pause",
                        systemImage: currentVM.isWorkoutPaused ? "play.fill" : "pause.fill"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    WorkoutSessionCompactChromeAccessibility.pauseResumeLabel(
                        isPaused: currentVM.isWorkoutPaused
                    )
                )
                .accessibilityHint(
                    WorkoutSessionCompactChromeAccessibility.pauseResumeHint(
                        isPaused: currentVM.isWorkoutPaused
                    )
                )

                Button(action: onOpen) {
                    Label("Log Sets", systemImage: "arrow.up.circle")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.success)
                .accessibilityLabel("Log Sets")
                .accessibilityHint("Opens the workout sheet to record sets")

                Button(role: .destructive, action: onFinish) {
                    Label("Finish", systemImage: "checkmark.circle")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Starts finish checks; saves to history if you confirm")
            }
            .padding(.top, 4)
        }
        .homeCardTier(.primary)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(FitlogPalette.success.opacity(pulsePhase ? 0.55 : 0.25), lineWidth: 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pauseResumeHapticTick)
    }
}
