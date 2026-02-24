//
//  FitLogApp.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import UserNotifications

@main
struct FitLogApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var dataVM = DataManager()
    @StateObject private var currentVM = CurrentWorkoutSessionViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
    }
}
