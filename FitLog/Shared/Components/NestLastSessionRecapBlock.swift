//
//  NestLastSessionRecapBlock.swift
//  FitLog
//
//  Compact last-session recap + Start this workout for Daily Adjust,
//  Body measurements, and Progress photos — not Home week strip, Coach,
//  More root, History drill-downs, Plan, or Subscription (other nightlies).
//

import SwiftUI

struct NestLastSessionRecapBlock: View {
    let recap: NestLastSessionWorkingCopy.Recap
    var startTitle: String = "Start this workout"
    var recapIdentifier: String
    var startIdentifier: String
    var startProminent: Bool = true
    var onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Last session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityHidden(true)
                Text(recap.workoutName)
                    .font(.headline)
                Text(recap.subtitleLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(recap.accessibilityLabel)
            .accessibilityIdentifier(recapIdentifier)
            if let onStart {
                startButton(onStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func startButton(_ action: @escaping () -> Void) -> some View {
        let label = Label(startTitle, systemImage: "play.fill")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        Group {
            if startProminent {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
            }
        }
        .accessibilityLabel(startTitle)
        .accessibilityHint("Starts a new session from \(recap.workoutName) and opens logging. Your History entry stays saved.")
        .accessibilityIdentifier(startIdentifier)
        .accessibilityAddTraits(.isButton)
    }
}

/// Self-contained last-session recap + Start that reads app environment so
/// Daily Adjust / Body measurements / Progress photos call sites stay additive.
struct NestLastSessionHost: View {
    var recapIdentifier: String
    var startIdentifier: String
    var caption: String?
    var startProminent: Bool = true
    var startTitle: String = "Start this workout"
    var onStartedWithoutReplace: (() -> Void)?
    var onAfterReplace: (() -> Void)?

    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var pendingStartFreshReplace: PendingWorkoutReplace?
    @State private var startFreshTrigger = 0

    var body: some View {
        Group {
            if let recap = lastSessionRecap {
                recapCard(recap)
            }
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartFreshReplace,
            onAfterReplace: {
                openCurrentWorkoutSheet?()
                onAfterReplace?()
            }
        )
        .sensoryFeedback(.impact, trigger: startFreshTrigger)
    }

    private func recapCard(_ recap: NestLastSessionWorkingCopy.Recap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NestLastSessionRecapBlock(
                recap: recap,
                startTitle: startTitle,
                recapIdentifier: recapIdentifier,
                startIdentifier: startIdentifier,
                startProminent: startProminent,
                onStart: canStartLastSession ? { startLastSession() } : nil
            )
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var latestCompletedSession: WorkoutSession? {
        NestLastSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions)
    }

    private var lastSessionRecap: NestLastSessionWorkingCopy.Recap? {
        guard let session = latestCompletedSession else { return nil }
        return NestLastSessionWorkingCopy.recap(
            from: session,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartLastSession: Bool {
        guard let session = latestCompletedSession else { return false }
        return NestLastSessionWorkingCopy.sourceWorkout(
            session: session,
            library: dataVM.userWorkouts
        ) != nil
    }

    private func startLastSession() {
        guard let session = latestCompletedSession else { return }
        startFreshTrigger += 1
        pendingStartFreshReplace = nil
        NestLastSessionWorkingCopy.startFresh(
            from: session,
            dataVM: dataVM,
            currentVM: currentVM,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: { pendingStartFreshReplace = $0 }
        )
        if pendingStartFreshReplace == nil, currentVM.isInProgress {
            onStartedWithoutReplace?()
        }
    }
}

#Preview("Light") {
    NestLastSessionRecapBlock(
        recap: NestLastSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "185 lb × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.dailyAdjustLastSession,
        startIdentifier: FitLogA11yID.dailyAdjustStartThisWorkout,
        onStart: {}
    )
    .padding()
}

#Preview("Dark") {
    NestLastSessionRecapBlock(
        recap: NestLastSessionWorkingCopy.Recap(
            workoutName: "Zone 2",
            lastDoneLine: "Last done today",
            loadLine: "45 min",
            exerciseName: nil,
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.bodyMeasurementsLastSession,
        startIdentifier: FitLogA11yID.bodyMeasurementsStartThisWorkout,
        startProminent: false,
        onStart: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Large Type") {
    NestLastSessionRecapBlock(
        recap: NestLastSessionWorkingCopy.Recap(
            workoutName: "Legs A",
            lastDoneLine: "Last done 3d ago",
            loadLine: "225 lb × 5 reps",
            exerciseName: "Back Squat (High Bar)",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.progressPhotosLastSession,
        startIdentifier: FitLogA11yID.progressPhotosStartThisWorkout,
        onStart: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Locale DE") {
    NestLastSessionRecapBlock(
        recap: NestLastSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "85 kg × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.dailyAdjustLastSession,
        startIdentifier: FitLogA11yID.dailyAdjustStartThisWorkout,
        onStart: {}
    )
    .padding()
    .environment(\.locale, Locale(identifier: "de_DE"))
}
