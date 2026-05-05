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
    @StateObject private var aiService = AIService(apiKey: OpenAIConfig.apiKey, baseURL: OpenAIConfig.aiBaseURL, model: OpenAIConfig.aiModel)
    @StateObject private var dayMonitor = CalendarDayMonitor()
    @StateObject private var userPreferences = UserPreferences()

    let modelContainer: ModelContainer
    @State private var dataVM: DataManager
    @State private var currentVM: CurrentWorkoutSessionViewModel
    @State private var migrationError: Error?

    init() {
        var container: ModelContainer
        var migError: Error?

        do {
            let appSupport = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let storeURL = appSupport.appending(path: "FitLogData.store")
            let config = ModelConfiguration(url: storeURL)
            container = try ModelContainer(
                for: Schema(FitLogSchemaV2.models),
                migrationPlan: FitLogMigrationPlan.self,
                configurations: config
            )
        } catch {
            migError = error
            // Fallback to an in-memory container so the app can show the recovery sheet.
            container = (try? ModelContainer(
                for: Schema(FitLogSchemaV2.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )) ?? {
                fatalError("Cannot create even an in-memory ModelContainer: \(error)")
            }()
        }

        self.modelContainer = container

        // Run the existing pre-V2 UserDefaults→SwiftData migrations so users coming
        // from very old builds land on V1 before the V1→V2 custom stage fires.
        if migError == nil {
            let ctx = ModelContext(container)
            MigrationService.migrateIfNeeded(context: ctx)
            WorkoutMigrationService.migrateIfNeeded(context: ctx)
        }

        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)
        _dataVM = State(wrappedValue: dm)
        _currentVM = State(wrappedValue: vm)
        _migrationError = State(wrappedValue: migError)
    }

    var body: some Scene {
        WindowGroup {
            if let migError = migrationError {
                FitLogRecoverySheet(
                    error: migError,
                    onRestoreLatest: { restoreFromLatestBackup() },
                    onChooseFile: { /* Phase B: DataTransferService file import */ },
                    onReset: { resetAndRelaunch() }
                )
            } else if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
                    .environmentObject(dayMonitor)
                    .environmentObject(userPreferences)
                    .onAppear {
                        dataVM.healthSyncStatusMessage = dataVM.healthSyncService.statusMessage
                        if !FitLogUITestLaunch.isActive {
                            aiService.wakeProxyHostIfNeeded()
                        }
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
                if authVM.isLoggedIn, !FitLogUITestLaunch.isActive {
                    aiService.wakeProxyHostIfNeeded()
                }
            default:
                break
            }
        }
    }

    // MARK: - Recovery actions

    private func restoreFromLatestBackup() {
        guard let snapshot = FitLogMigrationPlan.readLatestBackup() else { return }
        let ctx = ModelContext(modelContainer)
        try? V2MigrationDecoder.decode(snapshot: snapshot, into: ctx)
        migrationError = nil
    }

    private func resetAndRelaunch() {
        let appSupport = URL.applicationSupportDirectory
        let storeURL = appSupport.appending(path: "FitLogData.store")
        try? FileManager.default.removeItem(at: storeURL)
        migrationError = nil
    }
}
