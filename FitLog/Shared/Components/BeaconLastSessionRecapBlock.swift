//
//  BeaconLastSessionRecapBlock.swift
//  FitLog
//
//  Compact last-session recap + Start this workout for New Exercise,
//  Coach chat history, and Apply Split — not Account, Custom build,
//  Guided Coach preview, New workout, Data & Integrations, heatmap,
//  Home Premium, Daily Adjust, Coach tab, More root, History
//  drill-downs, Plan, or Subscription (other nightlies).
//

import SwiftUI

struct BeaconLastSessionRecapBlock: View {
    let recap: BeaconLastSessionWorkingCopy.Recap
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
/// New Exercise / Coach chat history / Apply Split call sites stay additive.
struct BeaconLastSessionHost: View {
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

    private func recapCard(_ recap: BeaconLastSessionWorkingCopy.Recap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BeaconLastSessionRecapBlock(
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
        BeaconLastSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions)
    }

    private var lastSessionRecap: BeaconLastSessionWorkingCopy.Recap? {
        guard let session = latestCompletedSession else { return nil }
        return BeaconLastSessionWorkingCopy.recap(
            from: session,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartLastSession: Bool {
        guard let session = latestCompletedSession else { return false }
        return BeaconLastSessionWorkingCopy.sourceWorkout(
            session: session,
            library: dataVM.userWorkouts
        ) != nil
    }

    private func startLastSession() {
        guard let session = latestCompletedSession else { return }
        startFreshTrigger += 1
        pendingStartFreshReplace = nil
        BeaconLastSessionWorkingCopy.startFresh(
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
    BeaconLastSessionRecapBlock(
        recap: BeaconLastSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "185 lb × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.newExerciseSheetLastSession,
        startIdentifier: FitLogA11yID.newExerciseSheetStartThisWorkout,
        onStart: {}
    )
    .padding()
}

#Preview("Dark") {
    BeaconLastSessionRecapBlock(
        recap: BeaconLastSessionWorkingCopy.Recap(
            workoutName: "Zone 2",
            lastDoneLine: "Last done today",
            loadLine: "45 min",
            exerciseName: nil,
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.coachChatHistoryLastSession,
        startIdentifier: FitLogA11yID.coachChatHistoryStartThisWorkout,
        startProminent: false,
        onStart: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Large Type") {
    BeaconLastSessionRecapBlock(
        recap: BeaconLastSessionWorkingCopy.Recap(
            workoutName: "Legs A",
            lastDoneLine: "Last done 3d ago",
            loadLine: "225 lb × 5 reps",
            exerciseName: "Back Squat (High Bar)",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.applySplitLastSession,
        startIdentifier: FitLogA11yID.applySplitStartThisWorkout,
        onStart: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Locale DE") {
    BeaconLastSessionRecapBlock(
        recap: BeaconLastSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "85 kg × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        recapIdentifier: FitLogA11yID.newExerciseSheetLastSession,
        startIdentifier: FitLogA11yID.newExerciseSheetStartThisWorkout,
        onStart: {}
    )
    .padding()
    .environment(\.locale, Locale(identifier: "de_DE"))
}
