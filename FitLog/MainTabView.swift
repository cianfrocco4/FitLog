//
//  MainTabView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            ExercisesLibraryView().tabItem { Label("Exercises", systemImage: "list.bullet") }
        }
        .overlay(alignment: .bottom) {
            if currentVM.isInProgress { CurrentWorkoutCollapsedBar() }
        }
        .onAppear { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    }
}
