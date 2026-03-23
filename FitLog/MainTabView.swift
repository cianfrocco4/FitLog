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
        .overlay(alignment: .bottom) {
            if currentVM.isInProgress {
                CurrentWorkoutCollapsedBar()
                    .environmentObject(dataVM)
                    // Move the collapsed bar fully above the tab bar
                    // so it no longer overlaps or intercepts tab taps.
                    .padding(.bottom, 72)
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
