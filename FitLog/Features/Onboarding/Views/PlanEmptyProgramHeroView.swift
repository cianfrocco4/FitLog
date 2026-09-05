//
//  PlanEmptyProgramHeroView.swift
//  FitLog
//
//  Empty Plan calendar when the user has no program or weekly lineup yet.
//

import SwiftData
import SwiftUI

struct PlanEmptyProgramHeroView: View {
    var onBuildProgram: () -> Void
    var onNewWorkout: () -> Void

    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var pendingStartFreshReplace: PendingWorkoutReplace?
    @State private var startFreshTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No program yet")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Build a weekly program to fill this calendar, or create a workout first and assign it later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recap = lastSessionRecap {
                lastSessionCard(recap)
            }

            VStack(spacing: 10) {
                Button {
                    onBuildProgram()
                } label: {
                    Label("Build a weekly program", systemImage: "calendar.badge.clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("planEmpty.buildProgram")
                .accessibilityHint("Opens the program builder without leaving Plan")

                Button {
                    onNewWorkout()
                } label: {
                    Label("Create a workout", systemImage: "plus.rectangle.on.folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("planEmpty.newWorkout")
                .accessibilityHint("Opens Home to create a workout")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .accessibilityIdentifier("planEmpty.hero")
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartFreshReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
        .sensoryFeedback(.impact, trigger: startFreshTrigger)
    }

    private var latestCompletedSession: WorkoutSession? {
        EntryLastSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions)
    }

    private var lastSessionRecap: EntryLastSessionWorkingCopy.Recap? {
        guard let session = latestCompletedSession else { return nil }
        return EntryLastSessionWorkingCopy.recap(
            from: session,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartLastSession: Bool {
        guard let session = latestCompletedSession else { return false }
        return EntryLastSessionWorkingCopy.sourceWorkout(
            session: session,
            library: dataVM.userWorkouts
        ) != nil
    }

    private func lastSessionCard(_ recap: EntryLastSessionWorkingCopy.Recap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EntryLastSessionRecapBlock(
                recap: recap,
                startTitle: "Start this workout",
                recapIdentifier: FitLogA11yID.planEmptyLastSession,
                startIdentifier: FitLogA11yID.planEmptyStartThisWorkout,
                startProminent: true,
                onStart: canStartLastSession ? { startLastSession() } : nil
            )
            Text("You can train without a program. History stays saved.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func startLastSession() {
        guard let session = latestCompletedSession else { return }
        startFreshTrigger += 1
        EntryLastSessionWorkingCopy.startFresh(
            from: session,
            dataVM: dataVM,
            currentVM: currentVM,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: { pendingStartFreshReplace = $0 }
        )
    }
}

#if DEBUG
@MainActor
private enum PlanEmptyPreviewData {
    static func dataManager() -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return DataManager(modelContainer: container)
    }
}

#Preview("Light") {
    let dataVM = PlanEmptyPreviewData.dataManager()
    PlanEmptyProgramHeroView(onBuildProgram: {}, onNewWorkout: {})
        .padding()
        .environment(dataVM)
        .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
        .environmentObject(UserPreferences())
}

#Preview("Dark") {
    let dataVM = PlanEmptyPreviewData.dataManager()
    PlanEmptyProgramHeroView(onBuildProgram: {}, onNewWorkout: {})
        .padding()
        .environment(dataVM)
        .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
        .environmentObject(UserPreferences())
        .preferredColorScheme(.dark)
}
#endif
