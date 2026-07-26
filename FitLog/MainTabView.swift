//
//  MainTabView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct MainTabView: View {
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @EnvironmentObject var userPreferences: UserPreferences
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @State private var showCurrentWorkoutPullUp = false
    @State private var workoutSheetDetent: PresentationDetent = FitlogWorkoutSheetDetent.defaultOpen
    @State private var showOnboarding = false
    @State private var showPostWorkoutPaywall = false
    @State private var rootTab: FitlogRootTab = .home
    @State private var coachDeepLink: FitlogCoachDeepLink = .idle
    @State private var workoutChromeMetrics = WorkoutChromeMetrics()

    private var activeCoachTip: String? {
        guard userPreferences.hasCompletedOnboarding else { return nil }
        guard !currentVM.isInProgress else { return nil }
        guard !showOnboarding else { return nil }
        switch rootTab {
        case .home:
            guard !userPreferences.coachMarkHomeDismissed else { return nil }
            return "Home shows today’s plan, program tools, and your training week."
        case .plan:
            guard !userPreferences.coachMarkPlanDismissed else { return nil }
            return "Plan is your calendar—assign workouts and adjust how many sessions you want per week."
        case .history:
            guard !userPreferences.coachMarkHistoryDismissed else { return nil }
            return "History stores completed workouts, trends, and personal records."
        default:
            return nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
        TabView(selection: $rootTab) {
            HomeView()
                .workoutCollapsedBarInset()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(FitlogRootTab.home)
            PlanCalendarView()
                .workoutCollapsedBarInset()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(FitlogRootTab.plan)
            HistoryView()
                .workoutCollapsedBarInset()
                .tabItem { Label("History", systemImage: "chart.bar") }
                .tag(FitlogRootTab.history)
            AIChatView()
                .workoutCollapsedBarInset()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                .tag(FitlogRootTab.coach)
            MoreTabRootView()
                .environment(dataVM)
                .environment(currentVM)
                .environmentObject(userPreferences)
                .environmentObject(authVM)
                .workoutCollapsedBarInset()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(FitlogRootTab.more)
        }
        .environment(\.fitlogRootTabSelection, $rootTab)
        .environment(\.fitlogCoachDeepLink, $coachDeepLink)
        .environment(\.isCurrentWorkoutSheetPresented, showCurrentWorkoutPullUp)
        .environment(\.fitlogWorkoutSheetDetent, workoutSheetDetent)
        .environment(\.workoutChromeMetrics, workoutChromeMetrics)
        .environment(\.openCurrentWorkoutSheet, {
            currentVM.pendingPullUpFocus = nil
            showCurrentWorkoutPullUp = true
        })
        .environment(\.openPullUpToExerciseLogIndex, { logIndex in
            currentVM.pendingPullUpFocus = PendingPullUpFocus(exerciseLogIndex: logIndex, presentLogSetSheet: true)
            showCurrentWorkoutPullUp = true
        })

            if let tip = activeCoachTip {
                coachMarkBanner(message: tip)
                    .padding(.horizontal, 16)
                    .padding(.bottom, currentVM.isInProgress ? 88 : 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCurrentWorkoutPullUp) {
            CurrentWorkoutPullUpSheet(sheetDetent: $workoutSheetDetent)
                .environment(currentVM)
                .environment(dataVM)
                .environment(formGuideService)
                .environmentObject(aiService)
                .environmentObject(userPreferences)
                .presentationDetents(
                    FitlogWorkoutSheetDetent.all,
                    selection: $workoutSheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: FitlogWorkoutSheetDetent.expanded))
                .interactiveDismissDisabled()
        }
        .onChange(of: showCurrentWorkoutPullUp) { _, isOpen in
            if isOpen {
                withAnimation(.easeInOut(duration: 0.35)) {
                    workoutSheetDetent = FitlogWorkoutSheetDetent.defaultOpen
                }
            }
        }
        .onChange(of: workoutSheetDetent) { _, newDetent in
            if newDetent == FitlogWorkoutSheetDetent.collapsed {
                showCurrentWorkoutPullUp = false
            }
        }
        .sheet(item: Binding(
            get: { currentVM.pendingWorkoutCompletionSummary },
            set: { currentVM.pendingWorkoutCompletionSummary = $0 }
        )) { summary in
            WorkoutCompletionSummaryView(summary: summary) {
                currentVM.pendingWorkoutCompletionSummary = nil
                maybePresentPostWorkoutPaywall()
            }
            .environmentObject(userPreferences)
        }
        .sheet(isPresented: $showPostWorkoutPaywall) {
            PaywallView(triggerFeature: .aiCoach, onDismiss: {
                userPreferences.hasSeenPostWorkoutPaywall = true
            })
            .environment(entitlementStore)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(isPresented: $showOnboarding) { action in
                switch action {
                case .none:
                    break
                case .coachAISplit:
                    rootTab = .coach
                    coachDeepLink = .openDynamicProgramBuilder(prefill: nil)
                case .homeNewWorkoutTemplates:
                    rootTab = .home
                    NotificationCenter.default.post(
                        name: .fitlogPresentNewWorkout,
                        object: NewWorkoutLaunchHint.templatesFirst
                    )
                case .homeNewWorkoutScratch:
                    rootTab = .home
                    NotificationCenter.default.post(
                        name: .fitlogPresentNewWorkout,
                        object: NewWorkoutLaunchHint.buildOwnFirst
                    )
                case .homeCardioQuickStart:
                    rootTab = .home
                    NotificationCenter.default.post(
                        name: .fitlogPresentNewWorkout,
                        object: NewWorkoutLaunchHint.cardioFirst
                    )
                }
            }
            .environment(dataVM)
            .environmentObject(userPreferences)
            .environment(entitlementStore)
            .interactiveDismissDisabled()
        }
        .onChange(of: currentVM.isInProgress) { wasActive, isActive in
            if isActive && !wasActive {
                showCurrentWorkoutPullUp = true
            }
            if !isActive {
                showCurrentWorkoutPullUp = false
            }
        }
        .onChange(of: dayMonitor.currentDayKey) { _, _ in
            dataVM.freezeYesterdayPlanAssignmentIfNeeded()
            dataVM.reconcileSkippedCycleTrainingDays()
        }
        .onAppear {
            if FitLogUITestLaunch.isActive {
                userPreferences.applyUITestDefaults()
            } else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
            if !userPreferences.hasCompletedOnboarding, !dataVM.completedSessions.isEmpty {
                userPreferences.markOnboardingComplete()
            } else if !FitLogUITestLaunch.isActive, !userPreferences.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .alert(
            "Could not save",
            isPresented: Binding(
                get: { dataVM.persistenceFailureReporter.alertMessage != nil },
                set: { if !$0 { dataVM.persistenceFailureReporter.clear() } }
            )
        ) {
            Button("OK", role: .cancel) {
                dataVM.persistenceFailureReporter.clear()
            }
        } message: {
            Text(dataVM.persistenceFailureReporter.alertMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .fitlogWorkoutCompleted)) { _ in
            guard !userPreferences.hasLoggedFirstWorkout else { return }
            userPreferences.hasLoggedFirstWorkout = true
            AnalyticsService.shared.track(.firstWorkoutLogged)
        }
        .onOpenURL { url in
            guard let link = FitLogDeepLink(url: url) else { return }
            switch link {
            case .quickLog:
                rootTab = .home
                if currentVM.isInProgress {
                    showCurrentWorkoutPullUp = true
                } else {
                    NotificationCenter.default.post(name: .fitlogPresentNewWorkout, object: nil)
                }
            }
        }
    }

    private func maybePresentPostWorkoutPaywall() {
        guard !entitlementStore.isPremium else { return }
        guard !userPreferences.hasSeenPostWorkoutPaywall else { return }
        guard userPreferences.hasTriggeredReadinessInsight else { return }
        guard !dataVM.completedSessions.isEmpty else { return }
        userPreferences.hasSeenPostWorkoutPaywall = true
        showPostWorkoutPaywall = true
    }

    private func coachMarkBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tip")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
            Button("Got it") {
                switch rootTab {
                case .home: userPreferences.coachMarkHomeDismissed = true
                case .plan: userPreferences.coachMarkPlanDismissed = true
                case .history: userPreferences.coachMarkHistoryDismissed = true
                default: break
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
