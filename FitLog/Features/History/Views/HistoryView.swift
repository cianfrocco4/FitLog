//
//  HistoryView.swift
//  FitLog
//

import SwiftUI

struct HistoryView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @State private var viewModel = HistoryViewModel()
    @State private var isSearchPresented = false
    @State private var openedHistorySessionID: UUID?

    private var sessionsContentRevision: Int {
        HistoryAggregator.contentRevision(for: dataVM.completedSessions)
    }

    var body: some View {
        NavigationStack {
            List {
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
        }
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
