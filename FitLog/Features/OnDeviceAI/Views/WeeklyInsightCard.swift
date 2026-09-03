//
//  WeeklyInsightCard.swift
//  FitLog
//

import SwiftUI

struct WeeklyInsightCard: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var viewModel = InsightsViewModel()
    @State private var pendingStartReplace: PendingWorkoutReplace?
    @State private var startWorkoutTrigger = 0
    var readinessTrendSummaries: [String] = []

    private var lastSession: WorkoutSession? {
        LastCompletedSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions)
    }

    private var lastSessionRecap: LastCompletedSessionWorkingCopy.Recap? {
        guard let session = lastSession else { return nil }
        return LastCompletedSessionWorkingCopy.recap(
            from: session,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartLastSession: Bool {
        guard let session = lastSession else { return false }
        return LastCompletedSessionWorkingCopy.sourceWorkout(
            session: session,
            library: dataVM.userWorkouts
        ) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Week in review", systemImage: "text.book.closed")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                } else if entitlementStore.isPremium {
                    Button("Refresh") {
                        Task {
                            await viewModel.regenerate(
                                dataVM: dataVM,
                                aiService: aiService,
                                entitlementStore: entitlementStore,
                                readinessTrendSummaries: readinessTrendSummaries
                            )
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityHint("Regenerates this week's insight")
                }
            }

            if let recap = lastSessionRecap {
                LastCompletedSessionRecapBlock(
                    recap: recap,
                    startTitle: "Start this workout",
                    recapIdentifier: FitLogA11yID.weeklyInsightLastSession,
                    startIdentifier: FitLogA11yID.weeklyInsightStartWorkout,
                    startProminent: false,
                    onStart: canStartLastSession ? { startLastSession() } : nil
                )
                Divider()
            }

            if let insight = viewModel.insight {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.narrative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !insight.highlights.isEmpty {
                    bulletBlock(title: "Highlights", items: insight.highlights, systemImage: "checkmark.circle")
                }
                if !insight.risks.isEmpty {
                    bulletBlock(title: "Watch", items: insight.risks, systemImage: "exclamationmark.triangle")
                }
                if !insight.nextActions.isEmpty {
                    bulletBlock(title: "Next", items: insight.nextActions, systemImage: "arrow.right.circle")
                }

                Text("Not medical advice · \(insight.routeUsed.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !entitlementStore.isPremium {
                Text("Premium unlocks a natural-language summary of your training week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("See Premium") { viewModel.showPaywall = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Generate a private summary of this week's training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Generate insight") {
                    Task {
                        await viewModel.loadCachedOrGenerate(
                            dataVM: dataVM,
                            aiService: aiService,
                            entitlementStore: entitlementStore,
                            readinessTrendSummaries: readinessTrendSummaries
                        )
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            if entitlementStore.isPremium {
                await viewModel.loadCachedOrGenerate(
                    dataVM: dataVM,
                    aiService: aiService,
                    entitlementStore: entitlementStore,
                    readinessTrendSummaries: readinessTrendSummaries
                )
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(triggerFeature: .aiCoach, analyticsSource: "weekly_insight")
                .environment(entitlementStore)
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
        .sensoryFeedback(.impact, trigger: startWorkoutTrigger)
        .accessibilityElement(children: .contain)
    }

    private func startLastSession() {
        guard let session = lastSession else { return }
        startWorkoutTrigger += 1
        LastCompletedSessionWorkingCopy.startFresh(
            from: session,
            dataVM: dataVM,
            currentVM: currentVM,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: { pendingStartReplace = $0 }
        )
    }

    private func bulletBlock(title: String, items: [String], systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: systemImage)
                    .font(.caption)
            }
        }
    }
}
