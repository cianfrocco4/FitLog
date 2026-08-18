//
//  FitLogApp.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "FitLogApp"
)

@main
struct FitLogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var aiService = AIService(apiKey: OpenAIConfig.apiKey, baseURL: OpenAIConfig.aiBaseURL, model: OpenAIConfig.aiModel)
    @State private var formGuideService = ExerciseFormGuideService()
    @StateObject private var dayMonitor = CalendarDayMonitor()
    @StateObject private var userPreferences = UserPreferences()
    @State private var entitlementStore = EntitlementStore()

    /// Live container backing `dataVM`; replaced after a successful disk restore from backup.
    @State private var activeModelContainer: ModelContainer
    @State private var dataVM: DataManager
    @State private var currentVM: CurrentWorkoutSessionViewModel
    @State private var migrationError: Error?

    init() {
        let appSupport = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let storeURL = appSupport.appending(path: "FitLogData.store")
        let openResult = Self.openContainerWithRecovery(storeURL: storeURL)
        let container = openResult.container
        let migError = openResult.error

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
            if authVM.isLoggedIn || authVM.usesLocalOnlyMode {
                if let migError = migrationError {
                    FitLogRecoverySheet(
                        error: migError,
                        onRestoreLatest: { restoreFromLatestBackup() },
                        onRestoreFromFile: { url in restoreFromBackupFile(at: url) },
                        onReset: { resetAndRelaunch() }
                    )
                } else {
                    MainTabView()
                        .environmentObject(authVM)
                        .environment(dataVM)
                        .environment(currentVM)
                        .environment(entitlementStore)
                        .environmentObject(aiService)
                        .environment(formGuideService)
                        .environmentObject(dayMonitor)
                        .environmentObject(userPreferences)
                        .onReceive(NotificationCenter.default.publisher(for: .fitlogDidEraseUserData)) { _ in
                            userPreferences.resetFirstRunExperience()
                        }
                        .onAppear {
                            entitlementStore.configureIfNeeded()
                            // Skip RevenueCat identity sync under UI/unit tests — the host may
                            // mark entitlements configured without calling Purchases.configure.
                            if !FitLogUITestLaunch.isActive,
                               authVM.isLoggedIn,
                               let userID = authVM.revenueCatAppUserID {
                                Task { await entitlementStore.logIn(appUserID: userID) }
                            }
                            formGuideService.userPreferences = userPreferences
                            dataVM.healthSyncStatusMessage = dataVM.healthSyncService.statusMessage
                            dataVM.publishIntentExerciseLibrary()
                            dataVM.publishWidgetSnapshot()
                            currentVM.processPendingIntentActions()
                            if !FitLogUITestLaunch.isActive {
                                aiService.wakeProxyHostIfNeeded()
                                formGuideService.wakeProxyAndRetryIfNeeded()
                                if currentVM.isInProgress {
                                    formGuideService.startKeepAlive()
                                }
                            }
                        }
                        .onChange(of: currentVM.isInProgress) { _, inProgress in
                            if FitLogUITestLaunch.isActive { return }
                            if inProgress {
                                formGuideService.startKeepAlive()
                            } else {
                                formGuideService.stopKeepAlive()
                            }
                        }
                }
            } else {
                LoginView()
                    .environmentObject(authVM)
                    .environment(entitlementStore)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                currentVM.appDidEnterBackground()
                if (authVM.isLoggedIn || authVM.usesLocalOnlyMode), !FitLogUITestLaunch.isActive {
                    formGuideService.stopKeepAlive()
                }
            case .active:
                currentVM.appDidBecomeActive()
                currentVM.processPendingIntentActions()
                if authVM.isLoggedIn || authVM.usesLocalOnlyMode, !FitLogUITestLaunch.isActive {
                    aiService.wakeProxyHostIfNeeded()
                    formGuideService.wakeProxyAndRetryIfNeeded()
                    if currentVM.isInProgress {
                        formGuideService.startKeepAlive()
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - Container open + recovery

    /// Opens the on-disk store, attempting silent backup restore or a fresh start before surfacing recovery UI.
    static func openContainerWithRecovery(storeURL: URL) -> (container: ModelContainer, error: Error?) {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: FitLogMigrationPlan.self,
                configurations: config
            )
            return (container, nil)
        } catch {
            let originalError = error

            if let snapshot = FitLogMigrationPlan.readBestAvailableRecoverySnapshot() {
                removeStoreArtifacts(at: storeURL)
                if let fresh = try? ModelContainer(
                    for: schema,
                    migrationPlan: FitLogMigrationPlan.self,
                    configurations: config
                ) {
                    let ctx = ModelContext(fresh)
                    if (try? V2MigrationDecoder.decode(snapshot: snapshot, into: ctx)) != nil {
                        log.notice("Migration failed but auto-recovered from backup")
                        return (fresh, nil)
                    }
                }
            }

            // Preserve the corrupt on-disk store and surface recovery UI instead of wiping user data.
            log.error("Migration failed with no backup available — preserving store for recovery UI")
            let memWithPlan = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let memNoPlan = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            if let c = try? ModelContainer(
                for: schema,
                migrationPlan: FitLogMigrationPlan.self,
                configurations: memWithPlan
            ) {
                return (c, originalError)
            }
            if let c = try? ModelContainer(for: schema, configurations: memNoPlan) {
                return (c, originalError)
            }
            fatalError("Cannot create even an in-memory ModelContainer: \(originalError)")
        }
    }

    // MARK: - Recovery actions

    private static func persistedStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "FitLogData.store")
    }

    /// Removes a SwiftData/SQLite store and any `-wal` / `-shm` sidecars.
    static func removeStoreArtifacts(at storeURL: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Removes the main SwiftData/SQLite store and any `-wal` / `-shm` sidecars.
    private static func removePersistedStoreArtifacts() {
        removeStoreArtifacts(at: persistedStoreURL())
    }

    /// Restores from the best available `BackupSnapshot` under Application Support/Backups (V1→V2, unified-slots, or rotating `backup_*.json`).
    /// Deletes the broken on-disk store, imports the snapshot into a new disk-backed container, saves, and rebinds `dataVM` / `currentVM`.
    /// - Returns `true` if a snapshot was found, decoded, and persisted to disk; then clears `migrationError`.
    @discardableResult
    private func restoreFromLatestBackup() -> Bool {
        guard let snapshot = FitLogMigrationPlan.readBestAvailableRecoverySnapshot() else { return false }
        return restoreFromSnapshot(snapshot)
    }

    /// Restores from a user-selected `.fitlog` or `.json` backup file.
    @discardableResult
    private func restoreFromBackupFile(at url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { return false }
        let format = DataTransferService.inferFormat(from: url) ?? .json
        guard format == .json else { return false }
        guard let snapshot = try? DataTransferService.importSnapshot(from: data, format: .json) else { return false }
        return restoreFromSnapshot(snapshot)
    }

    /// Validates, replaces the on-disk store, imports `snapshot`, and rebinds app state.
    @discardableResult
    private func restoreFromSnapshot(_ snapshot: BackupSnapshot) -> Bool {
        do {
            let probeCtx = ModelContext(activeModelContainer)
            try V2MigrationDecoder.decode(snapshot: snapshot, into: probeCtx)
        } catch {
            return false
        }

        Self.removePersistedStoreArtifacts()

        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
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
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
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
