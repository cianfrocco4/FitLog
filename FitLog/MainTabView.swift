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
            if currentVM.isInProgress {
                CurrentWorkoutCollapsedBar()
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
