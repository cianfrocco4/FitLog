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
    @State private var showCurrentWorkoutPullUp = false
    @State private var rootTab: FitlogRootTab = .home
    @State private var coachDeepLink: FitlogCoachDeepLink = .idle

    var body: some View {
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
        .sheet(isPresented: $showCurrentWorkoutPullUp) {
            CurrentWorkoutPullUpSheet()
                .environmentObject(currentVM)
                .environmentObject(dataVM)
                .environmentObject(aiService)
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
            guard !FitLogUITestLaunch.isActive else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
