//
//  MainTabView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @EnvironmentObject var userPreferences: UserPreferences
    @State private var showCurrentWorkoutPullUp = false
    @State private var showOnboarding = false
    @State private var rootTab: FitlogRootTab = .home
    @State private var coachDeepLink: FitlogCoachDeepLink = .idle

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
                .tabItem { Label("Home", systemImage: "house") }
                .tag(FitlogRootTab.home)
            PlanCalendarView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(FitlogRootTab.plan)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar") }
                .tag(FitlogRootTab.history)
            AIChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                .tag(FitlogRootTab.coach)
            MoreTabRootView()
                .environmentObject(dataVM)
                .environmentObject(userPreferences)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(FitlogRootTab.more)
        }
        .environment(\.fitlogRootTabSelection, $rootTab)
        .environment(\.fitlogCoachDeepLink, $coachDeepLink)
        .environment(\.openCurrentWorkoutSheet, {
            currentVM.pendingPullUpFocus = nil
            showCurrentWorkoutPullUp = true
        })
        .environment(\.openPullUpToExerciseLogIndex, { logIndex in
            currentVM.pendingPullUpFocus = PendingPullUpFocus(exerciseLogIndex: logIndex, presentLogSetSheet: true)
            showCurrentWorkoutPullUp = true
        })
        .environment(\.fitlogWorkoutBarContentInset, currentVM.isInProgress ? FitlogWorkoutBarLayout.contentBottomPadding : 0)
        .overlay {
            if currentVM.isInProgress {
                WorkoutBarPassthroughOverlay(
                    showPullUp: $showCurrentWorkoutPullUp,
                    currentVM: currentVM,
                    dataVM: dataVM
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }

            if let tip = activeCoachTip {
                coachMarkBanner(message: tip)
                    .padding(.horizontal, 16)
                    .padding(.bottom, currentVM.isInProgress ? 88 : 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCurrentWorkoutPullUp) {
            CurrentWorkoutPullUpSheet()
                .environmentObject(currentVM)
                .environmentObject(dataVM)
                .environmentObject(aiService)
                .environmentObject(userPreferences)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(isPresented: $showOnboarding)
                .environmentObject(dataVM)
                .environmentObject(userPreferences)
                .interactiveDismissDisabled()
        }
        .onChange(of: currentVM.isInProgress) { _, inProgress in
            if !inProgress {
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
