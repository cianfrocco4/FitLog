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

    /// Live container backing `dataVM`; replaced after a successful disk restore from backup.
    @State private var activeModelContainer: ModelContainer
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
            // Explicit `.none` avoids CloudKit-backed store wiring that can fail schema open on some environments.
            let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            // Must use `Schema(versionedSchema:)` so the store version matches `SchemaMigrationPlan` / `VersionedSchema` (not the default 1.0.0 from `Schema([types])`).
            let schema = Schema(versionedSchema: FitLogSchemaV4.self)
            container = try ModelContainer(
                for: schema,
                migrationPlan: FitLogMigrationPlan.self,
                configurations: config
            )
        } catch {
            migError = error
            // Fallback: in-memory store so the app can show `FitLogRecoverySheet` with the **disk** error.
            // Never clear `migError` here — doing so showed an empty database with no explanation after a
            // failed on-disk migration (e.g. missing migration stage for a schema version bump).
            let schema = Schema(versionedSchema: FitLogSchemaV4.self)
            let memWithPlan = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let memNoPlan = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            if let c = try? ModelContainer(
                for: schema,
                migrationPlan: FitLogMigrationPlan.self,
                configurations: memWithPlan
            ) {
                container = c
            } else if let c = try? ModelContainer(for: schema, configurations: memNoPlan) {
                container = c
            } else {
                fatalError("Cannot create even an in-memory ModelContainer: \(error)")
            }
        }

        _activeModelContainer = State(initialValue: container)

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
            if authVM.isLoggedIn {
                if let migError = migrationError {
                    FitLogRecoverySheet(
                        error: migError,
                        onRestoreLatest: { restoreFromLatestBackup() },
                        onChooseFile: { /* Phase B: DataTransferService file import */ },
                        onReset: { resetAndRelaunch() }
                    )
                } else {
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

    private static func persistedStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "FitLogData.store")
    }

    /// Removes the main SwiftData/SQLite store and any `-wal` / `-shm` sidecars.
    private static func removePersistedStoreArtifacts() {
        let storeURL = persistedStoreURL()
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Restores from the best available `BackupSnapshot` under Application Support/Backups (V1→V2, unified-slots, or rotating `backup_*.json`).
    /// Deletes the broken on-disk store, imports the snapshot into a new disk-backed container, saves, and rebinds `dataVM` / `currentVM`.
    /// - Returns `true` if a snapshot was found, decoded, and persisted to disk; then clears `migrationError`.
    @discardableResult
    private func restoreFromLatestBackup() -> Bool {
        guard let snapshot = FitLogMigrationPlan.readBestAvailableRecoverySnapshot() else { return false }

        // Validate the snapshot decodes before deleting anything on disk.
        do {
            let probeCtx = ModelContext(activeModelContainer)
            try V2MigrationDecoder.decode(snapshot: snapshot, into: probeCtx)
        } catch {
            return false
        }

        Self.removePersistedStoreArtifacts()

        let schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let config = ModelConfiguration(url: Self.persistedStoreURL(), cloudKitDatabase: .none)
        guard let freshContainer = try? ModelContainer(
            for: schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: config
        ) else {
            return false
        }

        let diskCtx = ModelContext(freshContainer)
        do {
            try V2MigrationDecoder.decode(snapshot: snapshot, into: diskCtx)
            try diskCtx.save()
            MigrationService.migrateIfNeeded(context: diskCtx)
            WorkoutMigrationService.migrateIfNeeded(context: diskCtx)
            try diskCtx.save()
        } catch {
            return false
        }

        let freshDM = DataManager(modelContainer: freshContainer)
        let freshCurrent = CurrentWorkoutSessionViewModel(dataManager: freshDM)
        activeModelContainer = freshContainer
        dataVM = freshDM
        currentVM = freshCurrent
        migrationError = nil
        return true
    }

    /// Wipes the on-disk store (including WAL/SHM), opens an empty database, and rebinds app state so the user can continue without restarting.
    private func resetAndRelaunch() {
        Self.removePersistedStoreArtifacts()
        let schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let config = ModelConfiguration(url: Self.persistedStoreURL(), cloudKitDatabase: .none)
        guard let freshContainer = try? ModelContainer(
            for: schema,
            migrationPlan: FitLogMigrationPlan.self,
            configurations: config
        ) else {
            return
        }
        let ctx = ModelContext(freshContainer)
        MigrationService.migrateIfNeeded(context: ctx)
        WorkoutMigrationService.migrateIfNeeded(context: ctx)
        try? ctx.save()

        let freshDM = DataManager(modelContainer: freshContainer)
        let freshCurrent = CurrentWorkoutSessionViewModel(dataManager: freshDM)
        activeModelContainer = freshContainer
        dataVM = freshDM
        currentVM = freshCurrent
        migrationError = nil
    }
}
