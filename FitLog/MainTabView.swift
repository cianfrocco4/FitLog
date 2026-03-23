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

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            PlanCalendarView().tabItem { Label("Plan", systemImage: "calendar") }
            HistoryView().tabItem { Label("History", systemImage: "chart.bar") }
            ExercisesLibraryView().tabItem { Label("Exercises", systemImage: "list.bullet") }
            AIChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
        }
        // Reserve layout space for the in-progress workout strip so tab content
        // (Coach composer, lists, etc.) stays above it instead of sitting underneath.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if currentVM.isInProgress {
                CurrentWorkoutCollapsedBar()
                    .environmentObject(dataVM)
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
