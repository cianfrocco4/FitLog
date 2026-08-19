//
//  MainTabView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import UserNotifications

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
    @State private var spotlightTour = SpotlightTourController()
    @State private var spotlightAnchors: [SpotlightTarget: CGRect] = [:]
    @State private var pendingFirstRunSheet = false
    @State private var didApplyUITestHarness = false

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
            .overlay(alignment: .bottom) {
                planTabSpotlightProbe
            }

            if spotlightTour.isActive, !showOnboarding, !currentVM.isInProgress {
                SpotlightOverlay(
                    controller: spotlightTour,
                    anchors: spotlightAnchors,
                    onFinished: {
                        userPreferences.markSpotlightTourCompleted()
                    }
                )
                .transition(.opacity)
            }
        }
        .coordinateSpace(name: SpotlightCoordinateSpace.name)
        .environment(spotlightTour)
        .onPreferenceChange(SpotlightAnchorPreferenceKey.self) { spotlightAnchors = $0 }
        .onAppear {
            spotlightTour.onComplete = {
                userPreferences.markSpotlightTourCompleted()
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
            WorkoutCompletionSummaryView(
                summary: summary,
                onDone: {
                    dismissWorkoutCompletion(summary: summary, kind: .done)
                },
                onViewInHistory: {
                    dismissWorkoutCompletion(summary: summary, kind: .viewInHistory)
                }
            )
            .environmentObject(userPreferences)
        }
        .sheet(isPresented: $showPostWorkoutPaywall) {
            PaywallView(
                triggerFeature: .aiCoach,
                analyticsSource: "post_workout",
                onDismiss: {
                    userPreferences.hasSeenPostWorkoutPaywall = true
                }
            )
            .environment(entitlementStore)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(isPresented: $showOnboarding) { action in
                handlePostOnboarding(action)
            }
            .environment(dataVM)
            .environmentObject(userPreferences)
            .environment(entitlementStore)
            .interactiveDismissDisabled()
        }
        .onChange(of: showOnboarding) { _, presented in
            guard !presented, !pendingFirstRunSheet else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                startPendingSpotlight()
            }
        }
        .onChange(of: currentVM.isInProgress) { wasActive, isActive in
            if isActive && !wasActive {
                showCurrentWorkoutPullUp = true
            }
            if !isActive {
                showCurrentWorkoutPullUp = false
                if spotlightTour.hasQueuedTour {
                    startPendingSpotlight()
                }
            }
        }
        .onChange(of: dayMonitor.currentDayKey) { _, _ in
            dataVM.freezeYesterdayPlanAssignmentIfNeeded()
            dataVM.reconcileSkippedCycleTrainingDays()
        }
        .onAppear {
            if FitLogUITestLaunch.isActive {
                applyUITestStoreHarnessIfNeeded()
                if FitLogUITestLaunch.shouldForceOnboarding {
                    userPreferences.resetFirstRunExperience()
                } else if FitLogUITestLaunch.shouldSkipOnboarding {
                    userPreferences.applyUITestDefaults()
                }
            } else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
            if FitLogUITestLaunch.shouldForceOnboarding {
                showOnboarding = true
            } else if !userPreferences.hasCompletedOnboarding, !dataVM.completedSessions.isEmpty {
                userPreferences.markOnboardingComplete()
            } else if !userPreferences.hasCompletedOnboarding {
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
        .onReceive(NotificationCenter.default.publisher(for: .fitlogDidEraseUserData)) { _ in
            userPreferences.resetFirstRunExperience()
            spotlightTour.reset()
            pendingFirstRunSheet = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .fitlogStartPendingSpotlight)) { _ in
            startPendingSpotlight()
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
            case .open:
                rootTab = .home
            case .readiness:
                rootTab = .home
                NotificationCenter.default.post(name: .fitlogOpenReadinessDetail, object: nil)
            case .uitestTab(let tab):
                guard FitLogUITestLaunch.isActive else { return }
                rootTab = tab
            }
        }
    }

    /// Invisible probe matching the Plan tab item so the spotlight can cut out the tab bar.
    private var planTabSpotlightProbe: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / 5
            let barHeight: CGFloat = 49
            let barTop = geo.size.height - geo.safeAreaInsets.bottom - barHeight
            let planRect = CGRect(
                x: tabWidth,
                y: barTop,
                width: tabWidth,
                height: barHeight + geo.safeAreaInsets.bottom
            )
            Color.clear
                .preference(
                    key: SpotlightAnchorPreferenceKey.self,
                    value: [SpotlightTarget.planTab: planRect]
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func handlePostOnboarding(_ action: PostOnboardingRoutineAction) {
        switch action {
        case .none:
            pendingFirstRunSheet = false
            spotlightTour.queue(.explore)
        case .homeProgramBuilder:
            pendingFirstRunSheet = true
            rootTab = .home
            spotlightTour.queue(.afterProgram)
            presentFirstRunSheet {
                NotificationCenter.default.post(name: .fitlogPresentSplitBuilder, object: nil)
            }
        case .homeNewWorkout:
            pendingFirstRunSheet = true
            rootTab = .home
            spotlightTour.queue(.afterWorkout)
            presentFirstRunSheet {
                NotificationCenter.default.post(
                    name: .fitlogPresentNewWorkout,
                    object: NewWorkoutLaunchHint.templatesFirst
                )
            }
        }
    }

    private func presentFirstRunSheet(_ post: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            post()
        }
    }

    func startPendingSpotlight() {
        pendingFirstRunSheet = false
        spotlightTour.startIfQueued(
            alreadyCompleted: userPreferences.spotlightTourCompleted,
            hasProgram: dataVM.dynamicProgramState != nil,
            hasWorkouts: !dataVM.userWorkouts.isEmpty,
            workoutInProgress: currentVM.isInProgress
        )
    }

    private func dismissWorkoutCompletion(summary: WorkoutCompletionSummary, kind: WorkoutCompletionDismissKind) {
        currentVM.pendingWorkoutCompletionSummary = nil
        if kind == .viewInHistory {
            rootTab = .history
            NotificationCenter.default.post(
                name: .fitlogOpenHistorySession,
                object: summary.id
            )
        }
        if WorkoutCompletionNavigation.shouldOfferPostWorkoutPaywall(after: kind) {
            maybePresentPostWorkoutPaywall()
        }
    }

    private func maybePresentPostWorkoutPaywall() {
        guard PremiumPromptPolicy.shouldPresentPostWorkoutPaywall(
            isPremium: entitlementStore.isPremium,
            hasSeen: userPreferences.hasSeenPostWorkoutPaywall,
            completedCount: dataVM.completedSessions.count
        ) else { return }
        userPreferences.hasSeenPostWorkoutPaywall = true
        showPostWorkoutPaywall = true
    }

    private func applyUITestStoreHarnessIfNeeded() {
        guard !didApplyUITestHarness else { return }
        didApplyUITestHarness = true
        if currentVM.isInProgress {
            currentVM.cancelWorkout()
        }
        if FitLogUITestLaunch.shouldResetStore {
            dataVM.eraseAllAppData(createSafetyBackup: false)
            if let persona = FitLogUITestLaunch.persona {
                FitLogSimulatedUserSeeder.seed(persona, into: dataVM)
            }
            return
        }
        var tickOutcome: FitLogSimulatedUserLivingDay.Outcome?
        if FitLogUITestLaunch.isDailyLiving, let persona = FitLogUITestLaunch.persona {
            tickOutcome = FitLogSimulatedUserLivingDay.runTick(persona, into: dataVM)
        }
        if FitLogUITestLaunch.shouldWriteReview, let persona = FitLogUITestLaunch.persona {
            _ = FitLogSimulatedUserReviewer.run(persona, into: dataVM, tickOutcome: tickOutcome)
        }
    }
}
