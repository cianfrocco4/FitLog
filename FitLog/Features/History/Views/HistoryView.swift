//
//  HistoryView.swift
//  FitLog
//

import SwiftUI

struct HistoryView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @State private var viewModel = HistoryViewModel()
    @State private var isSearchPresented = false
    @State private var openedHistorySessionID: UUID?
    @State private var pendingStartFreshReplace: PendingWorkoutReplace?
    @State private var startFreshTrigger = 0

    private var sessionsContentRevision: Int {
        HistoryAggregator.contentRevision(for: dataVM.completedSessions)
    }

    var body: some View {
        NavigationStack {
            List {
                if let recap = lastSessionRecap {
                    Section {
                        LastCompletedSessionRecapBlock(
                            recap: recap,
                            startTitle: "Start this workout",
                            recapIdentifier: FitLogA11yID.historyTabLastSession,
                            startIdentifier: FitLogA11yID.historyTabStartThisWorkout,
                            startProminent: true,
                            onStart: canStartLastSession ? { startLastSession() } : nil
                        )
                    }
                }

                Section {
                    Picker("Section", selection: $viewModel.mainTab) {
                        ForEach(HistoryMainTab.allCases) { tab in
                            Text(tab.label).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch viewModel.mainTab {
                case .overview:
                    HistoryOverviewTab(viewModel: viewModel)
                case .sessions:
                    HistorySessionsTab(viewModel: viewModel)
                case .explore:
                    HistoryExploreTab(viewModel: viewModel)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HistoryFilterMenu(viewModel: viewModel)
                }
            }
            .searchable(
                text: searchBinding,
                isPresented: Binding(
                    get: { viewModel.mainTab != .overview && isSearchPresented },
                    set: { isSearchPresented = $0 }
                ),
                prompt: searchPrompt
            )
            .navigationDestination(item: $openedHistorySessionID) { sessionID in
                if let session = dataVM.completedSessions.first(where: { $0.id == sessionID }) {
                    SessionDetailView(session: session)
                        .environment(dataVM)
                        .environment(currentVM)
                } else {
                    ContentUnavailableView(
                        "Workout not found",
                        systemImage: "chart.bar",
                        description: Text("This session is no longer in History.")
                    )
                }
            }
            .onAppear {
                clampDayRangeForSubscriptionTier()
                dataVM.refreshCompletedSessions()
                viewModel.recompute(dataVM: dataVM)
                loadTabDataIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .fitlogOpenHistorySession)) { note in
                guard let sessionID = note.object as? UUID else { return }
                openHistorySession(id: sessionID)
            }
            .onChange(of: entitlementStore.isPremium) { _, _ in
                clampDayRangeForSubscriptionTier()
                viewModel.recompute(dataVM: dataVM)
            }
            .onChange(of: viewModel.dayRange) { _, _ in
                viewModel.recompute(dataVM: dataVM)
            }
            .onChange(of: viewModel.mainTab) { _, newTab in
                if newTab == .overview {
                    isSearchPresented = false
                    viewModel.exploreSearch = ""
                    viewModel.sessionsSearch = ""
                }
                loadTabDataIfNeeded()
            }
            .onChange(of: sessionsContentRevision) { _, _ in
                viewModel.recompute(dataVM: dataVM)
                loadTabDataIfNeeded()
            }
            .workoutReplaceConflictConfirmation(
                currentVM: currentVM,
                pending: $pendingStartFreshReplace,
                onAfterReplace: { openCurrentWorkoutSheet?() }
            )
            .sensoryFeedback(.impact, trigger: startFreshTrigger)
        }
    }

    private var latestCompletedSession: WorkoutSession? {
        LastCompletedSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions)
    }

    private var lastSessionRecap: LastCompletedSessionWorkingCopy.Recap? {
        guard let session = latestCompletedSession else { return nil }
        return LastCompletedSessionWorkingCopy.recap(
            from: session,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartLastSession: Bool {
        guard let session = latestCompletedSession else { return false }
        return LastCompletedSessionWorkingCopy.sourceWorkout(
            session: session,
            library: dataVM.userWorkouts
        ) != nil
    }

    private func startLastSession() {
        guard let session = latestCompletedSession else { return }
        startFreshTrigger += 1
        LastCompletedSessionWorkingCopy.startFresh(
            from: session,
            dataVM: dataVM,
            currentVM: currentVM,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: { pendingStartFreshReplace = $0 }
        )
    }

    private func openHistorySession(id: UUID) {
        viewModel.mainTab = .sessions
        dataVM.refreshCompletedSessions()
        viewModel.recompute(dataVM: dataVM)
        viewModel.ensureSessionsData(dataVM: dataVM)
        // Defer so the Sessions tab is on-screen before the push.
        DispatchQueue.main.async {
            openedHistorySessionID = id
        }
    }

    private func clampDayRangeForSubscriptionTier() {
        let clamped = HistoryDayRange.effectiveRange(
            selected: viewModel.dayRange,
            isPremium: entitlementStore.hasAccess(to: .unlimitedHistory)
        )
        if clamped != viewModel.dayRange {
            viewModel.dayRange = clamped
        }
        if !entitlementStore.hasAccess(to: .advancedAnalytics) {
            viewModel.comparePriorPeriod = false
        }
    }

    private func loadTabDataIfNeeded() {
        switch viewModel.mainTab {
        case .sessions:
            viewModel.ensureSessionsData(dataVM: dataVM)
        case .explore:
            viewModel.ensureExploreData(dataVM: dataVM)
        case .overview:
            break
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: {
                switch viewModel.mainTab {
                case .sessions: return viewModel.sessionsSearch
                case .explore: return viewModel.exploreSearch
                case .overview: return ""
                }
            },
            set: { newValue in
                switch viewModel.mainTab {
                case .sessions: viewModel.sessionsSearch = newValue
                case .explore: viewModel.exploreSearch = newValue
                case .overview: break
                }
            }
        )
    }

    private var searchPrompt: String {
        switch viewModel.mainTab {
        case .sessions: return "Search sessions"
        case .explore: return "Search workouts & exercises"
        case .overview: return ""
        }
    }
}
