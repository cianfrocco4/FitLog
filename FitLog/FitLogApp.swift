//
//  FitLogApp.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FitLogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var currentVM = CurrentWorkoutSessionViewModel()
    @StateObject private var aiService = AIService(apiKey: OpenAIConfig.apiKey, baseURL: OpenAIConfig.aiBaseURL, model: OpenAIConfig.aiModel)

    let modelContainer: ModelContainer
    @StateObject private var dataVM: DataManager

    init() {
        let container: ModelContainer
        do {
            let appSupport = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let storeURL = appSupport.appending(path: "FitLogData.store")
            let config = ModelConfiguration(url: storeURL)
            container = try ModelContainer(
                for: SDExercise.self, SDWorkout.self, SDWorkoutTemplate.self,
                     SDWorkoutSession.self, SDTrainingProgram.self, SDExerciseDisplayName.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = container

        let context = ModelContext(container)
        MigrationService.migrateIfNeeded(context: context)

        let dm = DataManager(modelContainer: container)
        _dataVM = StateObject(wrappedValue: dm)
    }

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
                    .environmentObject(aiService)
                    .onAppear {
                        currentVM.dataManager = dataVM
                        aiService.wakeProxyHostIfNeeded()
                    }
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                currentVM.appDidEnterBackground()
            case .active:
                currentVM.appDidBecomeActive()
                if authVM.isLoggedIn {
                    aiService.wakeProxyHostIfNeeded()
                }
            default:
                break
            }
        }
    }
}
