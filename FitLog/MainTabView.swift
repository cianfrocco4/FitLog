//
//  MainTabView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var aiService: AIService
    @State private var showCurrentWorkoutPullUp = false
    @State private var calendarDayRefresh = 0

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            PlanCalendarView().tabItem { Label("Plan", systemImage: "calendar") }
            HistoryView().tabItem { Label("History", systemImage: "chart.bar") }
            ExercisesLibraryView().tabItem { Label("Exercises", systemImage: "list.bullet") }
            AIChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
        }
        .environment(\.calendarDayRefresh, calendarDayRefresh)
        .environment(\.fitlogWorkoutBarContentInset, currentVM.isInProgress ? FitlogWorkoutBarLayout.contentBottomPadding : 0)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            calendarDayRefresh &+= 1
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                calendarDayRefresh &+= 1
            }
        }
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
        }
        .onChange(of: currentVM.isInProgress) { _, inProgress in
            if !inProgress {
                showCurrentWorkoutPullUp = false
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
