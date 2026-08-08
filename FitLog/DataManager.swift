//
//  DataManager.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//
//  Thin façade that composes focused stores (WorkoutStore, SessionStore,
//  ExerciseStore, TrainingProgramStore) while remaining the single
//  @EnvironmentObject injection point for all SwiftUI views.
//

import Foundation
import os
import SwiftData

private let unifiedSlotsMigrationLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.acianfrocco.FitLog",
    category: "UnifiedSlotsMigration"
)

private let cardioSchemaMigrationLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.acianfrocco.FitLog",
    category: "CardioSchemaMigration"
)

/// Captures a removed library row for Undo restore.
struct WorkoutExerciseDeletionSnapshot: Equatable {
    let workoutId: UUID
    let insertionIndex: Int
    let workoutExercise: WorkoutExercise
    let templateSlotId: UUID?
}

@Observable @MainActor
final class DataManager {
    var userWorkouts: [Workout] = []
    var globalExercises: [Exercise] = []
    private(set) var exerciseLocalDisplayNames: [UUID: String] = [:]
    var completedSessions: [WorkoutSession] = []
    var trainingProgram: TrainingProgramState = TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))
    /// Active periodized / dynamic program; when set, schedule fields sync into `trainingProgram`.
    var dynamicProgramState: DynamicProgramState?

    /// In-memory only: avoids duplicate block-transition toasts across reconciliations.
    private var lastNotifiedDynamicProgramId: UUID?
    private var lastNotifiedDynamicBlockId: UUID?

    let workoutStore: WorkoutStore
    let sessionStore: SessionStore
    let exerciseStore: ExerciseStore
    let programStore: TrainingProgramStore
    let dynamicProgramStore: DynamicProgramStore
    let splitPresetStore: SplitPresetStore
    let prStore: PersonalRecordStore
    let coachChatStore: CoachChatStore
    let readinessStore: ReadinessStore
    let healthSyncService: HealthKitSyncService
    let dataTransferService: DataTransferServiceClient
    var healthSyncEnabled: Bool = false
    var healthSyncStatusMessage: String?
    var persistenceFailureReporter: PersistenceFailureReporter

    private let bodyMetricsStore = BodyMetricsStore()
    var bodyMetricEntries: [BodyMetricEntry] = []
    var progressPhotoRecords: [ProgressPhotoRecord] = []

    // MARK: - Lifecycle

    init(modelContainer: ModelContainer) {
        let ctx = ModelContext(modelContainer)
        let failureReporter = PersistenceFailureReporter()
        self.workoutStore = WorkoutStore(modelContext: ctx)
        self.sessionStore = SessionStore(modelContext: ctx)
        self.exerciseStore = ExerciseStore(modelContext: ctx)
        self.programStore = TrainingProgramStore(modelContext: ctx)
        self.dynamicProgramStore = DynamicProgramStore(modelContext: ctx)
        self.splitPresetStore = SplitPresetStore(modelContext: ctx)
        self.prStore = PersonalRecordStore(modelContext: ctx)
        self.coachChatStore = CoachChatStore(modelContext: ctx, failureReporter: failureReporter)
        self.readinessStore = ReadinessStore(modelContext: ctx)
        self.healthSyncService = HealthKitSyncService()
        self.dataTransferService = DataTransferServiceClient(dataManagerProvider: { nil })
        self.persistenceFailureReporter = failureReporter
        loadAll()
        self.dataTransferService.attachDataManager(self)
        healthSyncEnabled = healthSyncService.syncEnabled
        healthSyncStatusMessage = healthSyncService.statusMessage
    }

    func loadAll() {
        globalExercises = exerciseStore.loadExercises()
        exerciseLocalDisplayNames = exerciseStore.loadDisplayNames()
        userWorkouts = workoutStore.loadWorkouts()
        completedSessions = sessionStore.loadSessions()

        if let program = programStore.loadProgram() {
            trainingProgram = program
        }

        if let dyn = dynamicProgramStore.loadActiveState() {
            dynamicProgramState = dyn
            syncTrainingProgramFromDynamicProgram()
            saveTrainingProgram()
        } else {
            dynamicProgramState = nil
        }

        pruneStaleFrozenCalendarDays()

        if globalExercises.isEmpty {
            preloadFullExerciseLibrary()
        }
        preloadCardioExerciseLibraryIfNeeded()

        migrateLegacyCustomExercises()
        backfillStrengthExerciseMetadataIfNeeded()
        migrateWorkoutsToUnifiedSlotsIfNeeded()
        migrateCardioSchemaIfNeeded()
        repairSessionConcreteSnapshotsIfNeeded()
        rotateBackup()
        freezeYesterdayPlanAssignmentIfNeeded()
        reconcileSkippedCycleTrainingDays()
        publishIntentExerciseLibrary()
        reloadBodyAndPhotosFromDisk()
    }

    /// Converts legacy `.concrete` rows in **library workouts and historical session snapshots** to `.flexible` blueprints. Runs once (UserDefaults flag).
    /// Session snapshots were previously omitted, which left History decoding fragile and could strand plan/session data out of sync with the library model.
    private func migrateWorkoutsToUnifiedSlotsIfNeeded() {
        let key = WorkoutUnifiedSlotsMigration.completedUserDefaultsKey
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let hasConcreteLibraryRow = userWorkouts.contains { workout in
            workout.exercises.contains { we in
                if case .concrete = we.resolution { return true }
                return false
            }
        }
        let hasConcreteSessionSnapshot = completedSessions.contains {
            WorkoutUnifiedSlotsMigration.embeddedWorkoutHasConcreteRow($0.workout)
        }

        if hasConcreteLibraryRow || hasConcreteSessionSnapshot {
            let snapshot = BackupSnapshot(
                schemaVersion: currentSchemaVersion,
                exercises: globalExercises,
                workouts: userWorkouts,
                sessions: completedSessions,
                program: trainingProgram,
                displayNames: exerciseLocalDisplayNames
            )
            guard WorkoutUnifiedSlotsMigration.writePreMigrationBackupVerified(snapshot) else {
                unifiedSlotsMigrationLog.error("Pre-migration backup missing or failed JSON verification; unified slots migration skipped.")
                return
            }
            unifiedSlotsMigrationLog.notice("Pre-migration backup written and verified (workouts=\(snapshot.workouts.count), sessions=\(snapshot.sessions.count)).")
        }

        var migratedLibrary = userWorkouts
        let libraryChanged = WorkoutUnifiedSlotsMigration.migrateWorkoutsInPlace(&migratedLibrary, globalExercises: globalExercises)

        var migratedSessions = completedSessions
        let sessionsChanged = WorkoutUnifiedSlotsMigration.migrateAllSessionsConcreteSnapshotsInPlace(
            &migratedSessions,
            globalExercises: globalExercises
        )

        if !libraryChanged && !sessionsChanged {
            UserDefaults.standard.set(true, forKey: key)
            unifiedSlotsMigrationLog.notice("Unified slots migration: no concrete rows in library or session snapshots; marked complete.")
            return
        }

        if libraryChanged {
            guard WorkoutUnifiedSlotsMigration.validateWorkoutsEncode(migratedLibrary) else {
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: migrated workouts failed to encode.")
                return
            }
            guard WorkoutUnifiedSlotsMigration.validateWorkoutsCodableRoundTrip(migratedLibrary) else {
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: workouts JSON round-trip failed.")
                return
            }
        }

        if sessionsChanged {
            guard WorkoutUnifiedSlotsMigration.validateSessionsCodableRoundTrip(migratedSessions) else {
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: migrated sessions failed JSON round-trip.")
                return
            }
        }

        let postSnapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: globalExercises,
            workouts: migratedLibrary,
            sessions: migratedSessions,
            program: trainingProgram,
            displayNames: exerciseLocalDisplayNames
        )
        guard WorkoutUnifiedSlotsMigration.validateFullSnapshotCodableRoundTrip(postSnapshot) else {
            unifiedSlotsMigrationLog.error("Unified slots migration aborted: full app snapshot round-trip failed.")
            return
        }

        if libraryChanged {
            guard WorkoutUnifiedSlotsMigration.libraryHasNoConcreteRows(migratedLibrary) else {
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: concrete rows still present in library after transform.")
                return
            }
        }

        let previousLibrary = userWorkouts
        let previousSessions = completedSessions

        if libraryChanged {
            userWorkouts = migratedLibrary
            guard saveWorkouts() else {
                userWorkouts = previousLibrary
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: SwiftData workout save failed.")
                return
            }
            let reloaded = workoutStore.loadWorkouts()
            guard Self.workoutsMatchAfterUnifiedMigration(persisted: reloaded, expected: migratedLibrary) else {
                userWorkouts = reloaded
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: reloaded workouts did not match migrated state; using disk. Will retry next launch.")
                return
            }
            guard WorkoutUnifiedSlotsMigration.libraryHasNoConcreteRows(reloaded) else {
                userWorkouts = reloaded
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: reloaded library still has concrete rows.")
                return
            }
            userWorkouts = reloaded
        }

        if sessionsChanged {
            completedSessions = migratedSessions
            guard sessionStore.saveSessions(completedSessions) else {
                completedSessions = previousSessions
                if libraryChanged {
                    userWorkouts = previousLibrary
                    _ = saveWorkouts()
                }
                unifiedSlotsMigrationLog.error("Unified slots migration aborted: SwiftData session save failed; reverted in-memory state.")
                return
            }
            let reloadedSessions = sessionStore.loadSessions()
            guard reloadedSessions.count == migratedSessions.count else {
                completedSessions = sessionStore.loadSessions()
                unifiedSlotsMigrationLog.error("Unified slots migration: session count mismatch after save; using disk state.")
                return
            }
            completedSessions = reloadedSessions
        }

        UserDefaults.standard.set(true, forKey: key)
        let finalWorkoutCount = userWorkouts.count
        let finalSessionCount = completedSessions.count
        unifiedSlotsMigrationLog.notice(
            "Unified slots migration completed (libraryWorkouts=\(finalWorkoutCount), sessions=\(finalSessionCount), libraryChanged=\(libraryChanged), sessionsChanged=\(sessionsChanged))."
        )
    }

    /// One-time cardio schema domain migration: backup, derive `workoutKind`, re-save if needed.
    private func migrateCardioSchemaIfNeeded() {
        let key = CardioSchemaMigration.completedUserDefaultsKey
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let snapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: globalExercises,
            workouts: userWorkouts,
            sessions: completedSessions,
            program: trainingProgram,
            displayNames: exerciseLocalDisplayNames
        )
        guard CardioSchemaMigration.writePreMigrationBackupVerified(snapshot) else {
            cardioSchemaMigrationLog.error("Pre-cardio backup missing or failed verification; cardio migration skipped.")
            return
        }
        cardioSchemaMigrationLog.notice(
            "Pre-cardio backup written (exercises=\(snapshot.exercises.count), workouts=\(snapshot.workouts.count), sessions=\(snapshot.sessions.count))."
        )

        var migratedWorkouts = userWorkouts
        var migratedSessions = completedSessions
        let changed = CardioSchemaMigration.normalizeInPlace(
            exercises: globalExercises,
            workouts: &migratedWorkouts,
            sessions: &migratedSessions
        )

        let postSnapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: globalExercises,
            workouts: migratedWorkouts,
            sessions: migratedSessions,
            program: trainingProgram,
            displayNames: exerciseLocalDisplayNames
        )
        guard CardioSchemaMigration.validateFullSnapshotCodableRoundTrip(postSnapshot) else {
            cardioSchemaMigrationLog.error("Cardio migration aborted: full snapshot round-trip failed.")
            return
        }

        if changed {
            let previousWorkouts = userWorkouts
            let previousSessions = completedSessions
            userWorkouts = migratedWorkouts
            guard saveWorkouts() else {
                userWorkouts = previousWorkouts
                cardioSchemaMigrationLog.error("Cardio migration aborted: workout save failed.")
                return
            }
            completedSessions = migratedSessions
            guard sessionStore.saveSessions(completedSessions) else {
                userWorkouts = previousWorkouts
                completedSessions = previousSessions
                _ = saveWorkouts()
                cardioSchemaMigrationLog.error("Cardio migration aborted: session save failed.")
                return
            }
            userWorkouts = workoutStore.loadWorkouts()
            completedSessions = sessionStore.loadSessions()
        }

        guard userWorkouts.count == snapshot.workouts.count,
              completedSessions.count == snapshot.sessions.count,
              globalExercises.count == snapshot.exercises.count else {
            cardioSchemaMigrationLog.error("Cardio migration aborted: count mismatch after save.")
            return
        }

        UserDefaults.standard.set(true, forKey: key)
        cardioSchemaMigrationLog.notice("Cardio schema migration completed (changed=\(changed)).")
    }

    /// Fixes users who already ran an older build that migrated the library but not embedded session workouts (History / round-trip issues).
    private func repairSessionConcreteSnapshotsIfNeeded() {
        guard UserDefaults.standard.bool(forKey: WorkoutUnifiedSlotsMigration.completedUserDefaultsKey) else { return }
        var sessions = completedSessions
        guard WorkoutUnifiedSlotsMigration.migrateAllSessionsConcreteSnapshotsInPlace(&sessions, globalExercises: globalExercises) else {
            return
        }
        guard WorkoutUnifiedSlotsMigration.validateSessionsCodableRoundTrip(sessions) else {
            unifiedSlotsMigrationLog.error("Session concrete repair aborted: JSON round-trip failed.")
            return
        }
        guard sessionStore.saveSessions(sessions) else {
            unifiedSlotsMigrationLog.error("Session concrete repair aborted: SwiftData save failed.")
            return
        }
        completedSessions = sessionStore.loadSessions()
        let repairedCount = completedSessions.count
        unifiedSlotsMigrationLog.notice("Repaired session snapshots: concrete→flexible (count=\(repairedCount)).")
    }

    /// Per-workout exercise row ids and counts must match after save → load.
    private static func workoutsMatchAfterUnifiedMigration(persisted: [Workout], expected: [Workout]) -> Bool {
        guard persisted.count == expected.count else { return false }
        let expectedById = Dictionary(uniqueKeysWithValues: expected.map { ($0.id, $0) })
        for w in persisted {
            guard let exp = expectedById[w.id] else { return false }
            guard w.exercises.count == exp.exercises.count else { return false }
            let idsP = Set(w.exercises.map(\.id))
            let idsE = Set(exp.exercises.map(\.id))
            guard idsP == idsE else { return false }
        }
        return true
    }

    // MARK: - Rotating backups

    private static let maxBackups = 7

    func rotateBackup() {
        let dir = URL.applicationSupportDirectory.appending(path: "Backups", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let snapshot = backupSnapshot()

        guard let data = try? JSONEncoder().encode(snapshot) else {
            #if DEBUG
            print("[Backup] Failed to encode snapshot")
            #endif
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "backup_\(formatter.string(from: Date())).json"
        let fileURL = dir.appending(path: fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[Backup] Write failed: \(error.localizedDescription)")
            #endif
        }

        Self.pruneRotatingBackups(in: dir, keepingNewest: Self.maxBackups)
    }

    /// Prunes only `backup_*.json` rotating snapshots. Migration safety files (`pre_v*`, unified-slots, etc.) are never deleted.
    nonisolated static func pruneRotatingBackups(in dir: URL, keepingNewest maxBackups: Int) {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let rotating = urls
            .filter { $0.lastPathComponent.hasPrefix("backup_") && $0.pathExtension.lowercased() == "json" }
            .filter { !FitLogMigrationPlan.isProtectedMigrationBackupFileName($0.lastPathComponent) }
            .sorted {
                let da = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }

        for old in rotating.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    // MARK: - Workouts

    @discardableResult
    func createWorkout(name: String) -> UUID {
        let newWorkout = Workout(id: UUID(), name: name, exercises: [])
        userWorkouts.append(newWorkout)
        saveWorkouts()
        return newWorkout.id
    }

    @discardableResult
    func createCardioWorkout(name: String, kind: WorkoutKind = .cardio) -> UUID {
        let newWorkout = Workout(id: UUID(), name: name, exercises: [], workoutKind: kind)
        userWorkouts.append(newWorkout)
        saveWorkouts()
        return newWorkout.id
    }

    func workout(id: UUID) -> Workout? {
        userWorkouts.first { $0.id == id }
    }

    func setWorkoutKind(_ workout: Workout, kind: WorkoutKind) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[index].workoutKind = kind
        saveWorkouts()
    }

    func refreshWorkoutKind(workoutId: UUID) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workoutId }) else { return }
        userWorkouts[index].workoutKind = WorkoutKind.derived(from: userWorkouts[index], exercises: globalExercises)
        saveWorkouts()
    }

    func uniqueWorkoutName(_ base: String, excludingWorkoutId: UUID? = nil) -> String {
        let names = Set(
            userWorkouts
                .filter { $0.id != excludingWorkoutId }
                .map(\.name)
        )
        return workoutStore.uniqueName(base, existingWorkoutNames: names, existingTemplateNames: names)
    }

    func applySplitBuilderTemplates(
        workouts: [(templateName: String, exercises: [(exercise: Exercise, sets: Int, reps: String)])],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        updateTrainingProgram: Bool,
        anchorDate: Date = Date()
    ) {
        var newIds: [UUID] = []
        for w in workouts {
            let name = uniqueWorkoutName(w.templateName)
            let id = createWorkout(name: name)
            newIds.append(id)
            for ex in w.exercises {
                guard let fresh = userWorkouts.first(where: { $0.id == id }) else { break }
                let sets = min(max(1, ex.sets), 10)
                let reps = ex.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                let repsFinal = reps.isEmpty ? "8-12" : reps
                _ = addExercise(
                    to: fresh,
                    exercise: ex.exercise,
                    recommendedSets: sets,
                    recommendedReps: repsFinal,
                    configurationFields: [],
                    recommendedConfigBySet: Array(repeating: [:], count: sets)
                )
            }
        }
        reorderWorkoutsPlacingIdsFirst(newIds)
        saveWorkouts()
        if updateTrainingProgram, !newIds.isEmpty {
            applyTrainingProgramSuggestion(
                cycleEntries: newIds.map { .workout($0) },
                sessionsPerWeek: sessionsPerWeek,
                preferredWeekdays: preferredWeekdays,
                anchorDate: anchorDate
            )
        }
    }

    func deleteWorkout(_ workout: Workout) {
        userWorkouts.removeAll { $0.id == workout.id }
        var p = trainingProgram
        mergeFrozenPastDays(from: p, into: &p.frozenCalendarDays, calendar: .current)
        p.cycleEntries.removeAll { $0.libraryWorkoutId == workout.id }
        trainingProgram = p
        saveWorkouts()
        saveTrainingProgram()
    }

    func renameWorkout(_ workout: Workout, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        let unique = uniqueWorkoutName(trimmed, excludingWorkoutId: workout.id)
        userWorkouts[index].name = unique
        saveWorkouts()
    }

    /// Slot blueprints in list order (flexible rows only).
    func flexibleSlots(from workout: Workout) -> [TemplateSlot] {
        workout.exercises.compactMap { we in
            guard case .flexible(let b) = we.resolution else { return nil }
            return b.asTemplateSlot()
        }
    }

    /// Appends a new flexible slot to a library workout. Returns the slot blueprint id, or nil if the workout was not found.
    @discardableResult
    func appendFlexibleSlot(toWorkoutId workoutId: UUID, slot: TemplateSlot) -> UUID? {
        guard let idx = userWorkouts.firstIndex(where: { $0.id == workoutId }) else { return nil }
        var w = userWorkouts[idx]
        let weId = UUID()
        w.exercises.append(
            WorkoutExercise(
                id: weId,
                resolution: .flexible(slot.asSlotBlueprint()),
                defaultRestTime: slot.defaultRestTime,
                recommendedSets: slot.recommendedSets,
                recommendedReps: slot.recommendedReps
            )
        )
        w.templateSlotIdByWorkoutExerciseId[weId] = slot.id
        userWorkouts[idx] = w
        saveWorkouts()
        return slot.id
    }

    /// Removes a flexible slot from the library workout by stable slot blueprint id.
    func removeFlexibleSlot(fromWorkoutId workoutId: UUID, slotId: UUID) {
        guard let idx = userWorkouts.firstIndex(where: { $0.id == workoutId }) else { return }
        var w = userWorkouts[idx]
        let rowsToRemove = w.exercises.filter { $0.templateSlotId == slotId }.map(\.id)
        w.exercises.removeAll { $0.templateSlotId == slotId }
        for rid in rowsToRemove {
            w.templateSlotIdByWorkoutExerciseId.removeValue(forKey: rid)
        }
        userWorkouts[idx] = w
        saveWorkouts()
    }

    /// Updates one flexible row’s blueprint (stable slot id).
    func updateFlexibleSlot(workoutId: UUID, slot: TemplateSlot) {
        guard let widx = userWorkouts.firstIndex(where: { $0.id == workoutId }) else { return }
        var w = userWorkouts[widx]
        guard let eidx = w.exercises.firstIndex(where: { $0.templateSlotId == slot.id }) else { return }
        var we = w.exercises[eidx]
        we.resolution = .flexible(slot.asSlotBlueprint())
        we.defaultRestTime = slot.defaultRestTime
        we.recommendedSets = slot.recommendedSets
        we.recommendedReps = slot.recommendedReps
        w.exercises[eidx] = we
        userWorkouts[widx] = w
        saveWorkouts()
    }

    func moveWorkout(from source: IndexSet, to destination: Int) {
        userWorkouts.move(fromOffsets: source, toOffset: destination)
        saveWorkouts()
    }

    @discardableResult
    func saveWorkouts() -> Bool {
        for i in userWorkouts.indices {
            userWorkouts[i].workoutKind = WorkoutKind.derived(from: userWorkouts[i], exercises: globalExercises)
        }
        let ok = workoutStore.saveWorkouts(userWorkouts)
        if !ok {
            persistenceFailureReporter.report("Could not save workouts. Your last change may not persist after you quit the app.")
        }
        return ok
    }

    // MARK: - Workouts with flexible (open) slots

    /// Creates a library workout whose rows are flexible slot blueprints (same shape as a migrated template).
    @discardableResult
    func createWorkoutWithFlexibleSlots(name: String, slots: [TemplateSlot] = []) -> UUID {
        let id = UUID()
        let w = Workout.fromLegacyTemplate(WorkoutTemplate(id: id, name: name, slots: slots))
        userWorkouts.append(w)
        saveWorkouts()
        return id
    }

    /// After applying a split, new workouts are created by appending. Home (and similar UIs) show a
    /// prefix of the library when the list is long, so users only saw older workouts. Move new ids
    /// to the front in proposal order, then persist.
    private func reorderWorkoutsPlacingIdsFirst(_ orderedLibraryIds: [UUID]) {
        guard !orderedLibraryIds.isEmpty else { return }
        let idSet = Set(orderedLibraryIds)
        var byId: [UUID: Workout] = [:]
        byId.reserveCapacity(userWorkouts.count)
        for w in userWorkouts { byId[w.id] = w }
        var head: [Workout] = []
        head.reserveCapacity(orderedLibraryIds.count)
        var placed = Set<UUID>()
        for id in orderedLibraryIds {
            guard !placed.contains(id), let w = byId[id] else { continue }
            placed.insert(id)
            head.append(w)
        }
        let tail = userWorkouts.filter { !idSet.contains($0.id) }
        userWorkouts = head + tail
    }

    func applyWorkoutSplitProposal(
        _ proposal: WorkoutSplitProposal,
        updateTrainingProgram: Bool,
        anchorDate: Date = Date()
    ) {
        var createdByPlanKey: [String: Exercise] = [:]
        var entries: [WorkoutPlanRef] = []
        for day in proposal.workouts {
            guard let id = createFlexWorkoutFromProposalDay(day, createdByPlanKey: &createdByPlanKey) else { continue }
            entries.append(.workout(id))
        }
        reorderWorkoutsPlacingIdsFirst(entries.map(\.libraryWorkoutId))
        saveWorkouts()
        if updateTrainingProgram, !entries.isEmpty {
            applyTrainingProgramSuggestion(
                cycleEntries: entries,
                sessionsPerWeek: proposal.sessionsPerWeek,
                preferredWeekdays: proposal.preferredWeekdays,
                anchorDate: anchorDate
            )
        }
    }

    /// Builds flexible `TemplateSlot` rows for one split proposal day (shared by split apply and dynamic program materialization).
    private func buildTemplateSlots(
        for day: WorkoutSplitProposalDay,
        createdByPlanKey: inout [String: Exercise]
    ) -> [TemplateSlot]? {
        func resolveOrCreateExercise(
            planName: String,
            overrideId: UUID?,
            musclesIfCreatingCustom: [MuscleGroup]
        ) -> Exercise? {
            if let oid = overrideId,
               let ex = globalExercises.first(where: { $0.id == oid }) {
                return ex
            }
            let trimmed = planName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard let result = ExerciseNameResolution.resolve(planName: trimmed, library: globalExercises) else { return nil }
            switch result {
            case .linked(let ex):
                return ex
            case .createCustom(let displayName):
                let key = ExerciseNameResolution.dedupeKey(forPlanName: displayName)
                if let cached = createdByPlanKey[key] { return cached }
                let muscles = musclesIfCreatingCustom.isEmpty ? [MuscleGroup.other] : musclesIfCreatingCustom
                let new = addNewExercise(name: displayName, description: "", muscles: muscles)
                createdByPlanKey[key] = new
                return new
            }
        }

        let slotSources: [WorkoutSplitProposalSlotItem] = {
            if !day.slots.isEmpty { return day.slots }
            return day.exercises.compactMap { ex in
                let n = ex.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !n.isEmpty else { return nil }
                let sets = min(max(1, ex.sets), 10)
                let repsRaw = ex.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                let reps = repsRaw.isEmpty ? "8-12" : repsRaw
                return WorkoutSplitProposalSlotItem(
                    label: n,
                    targetMuscleNames: [],
                    sets: sets,
                    reps: reps,
                    suggestedExerciseName: n,
                    suggestedExerciseOverrideId: ex.libraryExerciseOverrideId
                )
            }
        }()
        guard !slotSources.isEmpty else { return nil }

        let templateSlots: [TemplateSlot] = slotSources.map { s in
            let parsedMuscles = ExerciseNameResolution.resolveMuscleGroups(from: s.targetMuscleNames)
            let matchedExercise: Exercise? = {
                if let oid = s.suggestedExerciseOverrideId,
                   let ex = globalExercises.first(where: { $0.id == oid }) {
                    return ex
                }
                guard let raw = s.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                    return nil
                }
                let musclesForNew = parsedMuscles.isEmpty ? [MuscleGroup.other] : parsedMuscles
                return resolveOrCreateExercise(
                    planName: raw,
                    overrideId: nil,
                    musclesIfCreatingCustom: musclesForNew
                )
            }()
            let targetedMuscles: [MuscleGroup]
            if !parsedMuscles.isEmpty {
                targetedMuscles = parsedMuscles
            } else if let ex = matchedExercise, !ex.targetedMuscles.isEmpty {
                targetedMuscles = ex.targetedMuscles
            } else {
                targetedMuscles = [MuscleGroup.other]
            }
            let repsRaw = s.reps.trimmingCharacters(in: .whitespacesAndNewlines)
            let repsFinal = repsRaw.isEmpty ? "8-12" : repsRaw
            return TemplateSlot(
                label: s.label,
                targetedMuscles: targetedMuscles,
                exerciseRole: matchedExercise?.exerciseRole,
                movementPattern: matchedExercise?.movementPattern,
                defaultExerciseId: matchedExercise?.id,
                recommendedSets: min(max(1, s.sets), 10),
                recommendedReps: repsFinal
            )
        }
        return templateSlots
    }

    /// Creates one flexible-slot library workout from a proposal day. Returns nil when there is nothing to materialize.
    @discardableResult
    private func createFlexWorkoutFromProposalDay(
        _ day: WorkoutSplitProposalDay,
        createdByPlanKey: inout [String: Exercise]
    ) -> UUID? {
        guard let templateSlots = buildTemplateSlots(for: day, createdByPlanKey: &createdByPlanKey) else { return nil }
        let name = uniqueFlexWorkoutName(day.name)
        return createWorkoutWithFlexibleSlots(name: name, slots: templateSlots)
    }

    /// Creates library workouts for every `BlockWeeklyTemplate` in `program` (all blocks), keyed by template id.
    func materializeDynamicProgramWorkouts(for program: DynamicProgram) -> [UUID: UUID] {
        var createdByPlanKey: [String: Exercise] = [:]
        var map: [UUID: UUID] = [:]
        var orderedLibraryIds: [UUID] = []
        let isMultiBlock = program.blocks.count > 1
        for block in program.blocks {
            for template in block.weeklyTemplates {
                guard let wid = createFlexWorkoutFromBlockTemplate(
                    template,
                    blockName: block.name,
                    isMultiBlock: isMultiBlock,
                    createdByPlanKey: &createdByPlanKey
                ) else { continue }
                map[template.id] = wid
                orderedLibraryIds.append(wid)
            }
        }
        reorderWorkoutsPlacingIdsFirst(orderedLibraryIds)
        saveWorkouts()
        return map
    }

    @discardableResult
    private func createFlexWorkoutFromBlockTemplate(
        _ template: BlockWeeklyTemplate,
        blockName: String = "",
        isMultiBlock: Bool = false,
        createdByPlanKey: inout [String: Exercise]
    ) -> UUID? {
        guard !template.slots.isEmpty else { return nil }
        let templateSlots: [TemplateSlot] = template.slots.compactMap { slot in
            templateSlot(from: slot, createdByPlanKey: &createdByPlanKey)
        }
        guard !templateSlots.isEmpty else { return nil }
        let baseName = ProgramBlockNaming.materializedWorkoutName(
            dayName: template.dayName,
            blockName: blockName,
            isMultiBlock: isMultiBlock
        )
        let name = uniqueFlexWorkoutName(baseName)
        return createWorkoutWithFlexibleSlots(name: name, slots: templateSlots)
    }

    private func templateSlot(
        from slot: SplitBuilderEditableSlot,
        createdByPlanKey: inout [String: Exercise]
    ) -> TemplateSlot {
        let parsedMuscles = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
        let matchedExercise: Exercise? = {
            if let oid = slot.suggestedExerciseOverrideId,
               let ex = globalExercises.first(where: { $0.id == oid }) {
                return ex
            }
            guard let raw = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            guard let result = ExerciseNameResolution.resolve(planName: raw, library: globalExercises) else {
                return nil
            }
            switch result {
            case .linked(let ex):
                return ex
            case .createCustom(let displayName):
                let key = ExerciseNameResolution.dedupeKey(forPlanName: displayName)
                if let cached = createdByPlanKey[key] { return cached }
                let musclesForNew = parsedMuscles.isEmpty ? [MuscleGroup.other] : parsedMuscles
                let new = addNewExercise(name: displayName, description: "", muscles: musclesForNew)
                createdByPlanKey[key] = new
                return new
            }
        }()
        let targetedMuscles: [MuscleGroup]
        if !parsedMuscles.isEmpty {
            targetedMuscles = parsedMuscles
        } else if let ex = matchedExercise, !ex.targetedMuscles.isEmpty {
            targetedMuscles = ex.targetedMuscles
        } else {
            targetedMuscles = [.other]
        }
        let repsRaw = slot.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        let repsFinal = repsRaw.isEmpty ? (slot.modality == .cardio ? "—" : "8-12") : repsRaw
        return TemplateSlot(
            label: slot.label,
            targetedMuscles: targetedMuscles,
            exerciseRole: matchedExercise?.exerciseRole,
            movementPattern: matchedExercise?.movementPattern,
            defaultExerciseId: matchedExercise?.id,
            defaultRestTime: slot.restSeconds ?? 90,
            recommendedSets: min(max(1, slot.sets), 10),
            recommendedReps: repsFinal,
            cardioPrescription: slot.cardioPrescription
        )
    }

    /// Materializes templates, persists `DynamicProgramState`, and syncs the active block’s rotation into `trainingProgram`.
    @discardableResult
    func applyDynamicProgram(_ program: DynamicProgram, anchorDate: Date = Date()) -> Bool {
        let cal = Calendar.current
        let anchorStart = cal.startOfDay(for: anchorDate)
        let workoutsBeforeApply = userWorkouts
        let map = materializeDynamicProgramWorkouts(for: program)
        let templateIds = program.blocks.flatMap(\.weeklyTemplates).map(\.id)
        guard !templateIds.isEmpty, templateIds.allSatisfy({ map[$0] != nil }) else {
            userWorkouts = workoutsBeforeApply
            _ = saveWorkouts()
            return false
        }
        let state = DynamicProgramState(
            program: program,
            anchorDate: anchorStart,
            materializedTemplateWorkoutIds: map
        )
        setDynamicProgramState(state)
        return true
    }

    func uniqueFlexWorkoutName(_ base: String) -> String {
        uniqueWorkoutName(base.isEmpty ? "Workout" : base)
    }

    func updateWorkout(_ workout: Workout) {
        guard let idx = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[idx] = workout
        saveWorkouts()
    }

    /// Copy for an in-progress session: new ids when the library workout has flexible rows.
    func sessionInstance(from library: Workout, applyBlockProgression: Bool = true) -> Workout {
        let instance = workoutStore.sessionInstance(from: library, globalExercises: globalExercises)
        guard applyBlockProgression else { return instance }
        return CardioPeriodization.applyProgression(to: instance, blockContext: activeBlockContext())
    }

    func planLabel(for ref: WorkoutPlanRef) -> String {
        userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })?.name ?? "Missing workout"
    }

    /// Plan assignment shown on the calendar for `date`: frozen history before today (after rotation changes), else live engine resolution.
    /// Past days without a snapshot are unscheduled so the engine does not invent a split backward before you have any training history.
    func resolvedScheduleDay(for date: Date, calendar: Calendar = .current) -> ResolvedScheduleDay {
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        let dateStart = cal.startOfDay(for: date)
        if dateStart < todayStart {
            let key = TrainingProgramState.dayKey(for: date, calendar: cal)
            if let frozen = trainingProgram.frozenCalendarDays[key] {
                return frozen.asResolved()
            }
            return .unscheduled
        }

        let engine = TrainingScheduleEngine(calendar: cal)
        if let overridden = engine.resolveOverriddenDay(date: date, program: trainingProgram) {
            return overridden
        }

        if let dyn = dynamicProgramState {
            let pe = PeriodizationEngine(calendar: cal)
            let rd = pe.resolvedTemplateDay(on: date, state: dyn)
            if cal.isDate(dateStart, inSameDayAs: todayStart) {
                postDynamicProgramBlockTransitionIfNeeded(engine: pe, state: dyn, calendar: cal)
            }
            switch rd {
            case .rest:
                return .rest
            case .unscheduled:
                return .unscheduled
            case .training(let template), .flex(let template):
                if let wid = dyn.materializedTemplateWorkoutIds[template.id] {
                    return .workout(.workout(wid))
                }
                return .unscheduled
            }
        }

        return engine.defaultPlan(for: date, program: trainingProgram)
    }

    /// Block metadata for the given calendar day when a dynamic program is active (training day only).
    func activeBlockContext(on date: Date = Date(), calendar: Calendar = .current) -> BlockContext? {
        guard let state = dynamicProgramState else { return nil }
        return PeriodizationEngine(calendar: calendar).blockContext(on: date, state: state)
    }

    /// Completed vs planned **training sessions** in the active block through today (for Home progress UI).
    func dynamicProgramBlockSessionProgress(calendar: Calendar = .current) -> (completed: Int, planned: Int)? {
        guard let state = dynamicProgramState else { return nil }
        let cal = calendar
        let engine = PeriodizationEngine(calendar: cal)
        let today = cal.startOfDay(for: Date())
        guard let placement = engine.blockPlacement(on: today, state: state) else { return nil }
        let blockStart = engine.blockStartDate(blockIndex: placement.index, state: state)
        let blockEnd = min(engine.blockEndDate(blockIndex: placement.index, state: state), today)
        var completed = 0
        var planned = 0
        var walk = blockStart
        while walk <= blockEnd {
            let resolved = engine.resolvedTemplateDay(on: walk, state: state)
            switch resolved {
            case .training, .flex:
                planned += 1
                if primaryCompletedSession(on: walk, calendar: cal) != nil {
                    completed += 1
                }
            case .rest, .unscheduled:
                break
            }
            guard let nx = cal.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = nx
        }
        return (completed, max(1, planned))
    }

    /// Most recent completed session whose end (or start) falls on this local calendar day.
    func primaryCompletedSession(on date: Date, calendar: Calendar = .current) -> WorkoutSession? {
        let cal = calendar
        let key = TrainingProgramState.dayKey(for: date, calendar: cal)
        return completedSessions
            .filter(\.isCompleted)
            .filter { sessionDayKey($0, calendar: cal) == key }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    private func sessionDayKey(_ session: WorkoutSession, calendar: Calendar) -> String {
        let t = session.endTime ?? session.startTime
        return TrainingProgramState.dayKey(for: t, calendar: calendar)
    }

    /// For each local day strictly before today, records the current full resolution (including overrides) if not already frozen — so later split changes do not rewrite that day.
    /// Only days on or after the first completed workout are filled (or just yesterday when there are no logs) so we do not snapshot a fake cycle before you trained.
    private func mergeFrozenPastDays(from oldProgram: TrainingProgramState, into frozen: inout [String: FrozenPlanDay], calendar: Calendar = .current) {
        let engine = TrainingScheduleEngine(calendar: calendar)
        let todayStart = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return }

        let walkFrom: Date
        if let oldestLog = completedSessions.filter(\.isCompleted).map({ calendar.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            walkFrom = oldestLog
        } else {
            walkFrom = yesterday
        }

        var walk = walkFrom
        if let cap = calendar.date(byAdding: .year, value: -3, to: todayStart) {
            let capStart = calendar.startOfDay(for: cap)
            if walk < capStart { walk = capStart }
        }
        if walk > yesterday { return }

        while walk <= yesterday {
            let key = TrainingProgramState.dayKey(for: walk, calendar: calendar)
            if frozen[key] == nil {
                let r = engine.resolve(date: walk, program: oldProgram)
                frozen[key] = FrozenPlanDay(resolved: r)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = next
        }
    }

    /// Drops frozen snapshots that predate any training evidence (or, with no logs, anything before yesterday) so older app versions cannot leave years of invented plan cells.
    private func pruneStaleFrozenCalendarDays(calendar: Calendar = .current) {
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }

        var p = trainingProgram
        let floorKey: String
        if let oldest = completedSessions.filter(\.isCompleted).map({ cal.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            floorKey = TrainingProgramState.dayKey(for: oldest, calendar: cal)
        } else {
            floorKey = TrainingProgramState.dayKey(for: yesterday, calendar: cal)
        }

        let filtered = p.frozenCalendarDays.filter { $0.key >= floorKey }
        guard filtered.count != p.frozenCalendarDays.count else { return }
        p.frozenCalendarDays = filtered
        trainingProgram = p
        saveTrainingProgram()
    }

    private func applyTrainingProgramAfterFreezingPast(_ newProgram: TrainingProgramState) {
        var merged = newProgram
        mergeFrozenPastDays(from: trainingProgram, into: &merged.frozenCalendarDays, calendar: .current)
        trainingProgram = merged
        saveTrainingProgram()
    }

    /// Snapshots the previous local calendar day's plan (if not already frozen) using the current program. Call after the calendar day advances or on launch so "today" from yesterday does not remap when the split changes overnight.
    func freezeYesterdayPlanAssignmentIfNeeded(calendar: Calendar = .current) {
        guard completedSessions.contains(where: \.isCompleted) else { return }
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }
        let key = TrainingProgramState.dayKey(for: yesterday, calendar: cal)
        var p = trainingProgram
        guard p.frozenCalendarDays[key] == nil else { return }
        let r = TrainingScheduleEngine(calendar: cal).resolve(date: yesterday, program: p)
        p.frozenCalendarDays[key] = FrozenPlanDay(resolved: r)
        trainingProgram = p
        saveTrainingProgram()
    }

    // MARK: - Global exercises

    @discardableResult
    func addNewExercise(name: String, description: String, muscles: [MuscleGroup]) -> Exercise {
        let new = Exercise(id: UUID(), name: name, description: description, targetedMuscles: muscles, isCustom: true, configurationOptions: [])
        globalExercises.append(new)
        saveExercises()
        return new
    }

    @discardableResult
    func addNewCardioExercise(
        name: String,
        description: String,
        modality: ExerciseModality,
        metadata: CardioExerciseMetadata
    ) -> Exercise {
        let resolvedModality: ExerciseModality = modality == .strength ? .cardio : modality
        let new = Exercise(
            id: UUID(),
            name: name,
            description: description,
            targetedMuscles: [.other],
            isCustom: true,
            configurationOptions: [],
            modality: resolvedModality,
            cardioMetadata: metadata
        )
        globalExercises.append(new)
        saveExercises()
        return new
    }

    func updateExercise(_ exercise: Exercise) {
        guard let idx = globalExercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        globalExercises[idx] = exercise
        let snap = ExerciseSnapshot(from: exercise)
        for i in userWorkouts.indices {
            for j in userWorkouts[i].exercises.indices {
                guard userWorkouts[i].exercises[j].exerciseId == exercise.id else { continue }
                switch userWorkouts[i].exercises[j].resolution {
                case .concrete:
                    userWorkouts[i].exercises[j].resolution = .concrete(snap)
                case .flexible(var b):
                    b.defaultExerciseId = exercise.id
                    if b.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        b.label = exercise.name
                    }
                    b.targetedMuscles = exercise.targetedMuscles
                    b.exerciseRole = exercise.exerciseRole
                    b.movementPattern = exercise.movementPattern
                    userWorkouts[i].exercises[j].resolution = .flexible(b)
                }
            }
        }
        saveExercises()
        saveWorkouts()
    }

    func deleteGlobalExercise(_ exercise: Exercise) {
        clearLocalExerciseDisplayName(for: exercise.id)
        globalExercises.removeAll { $0.id == exercise.id }
        for i in userWorkouts.indices {
            var removedRowIds: [UUID] = []
            var newList: [WorkoutExercise] = []
            for var we in userWorkouts[i].exercises {
                if case .concrete(let s) = we.resolution, s.exerciseId == exercise.id {
                    removedRowIds.append(we.id)
                    continue
                }
                if case .flexible(var b) = we.resolution, b.defaultExerciseId == exercise.id {
                    b.defaultExerciseId = nil
                    we.resolution = .flexible(b)
                }
                newList.append(we)
            }
            userWorkouts[i].exercises = newList
            for rid in removedRowIds {
                userWorkouts[i].templateSlotIdByWorkoutExerciseId.removeValue(forKey: rid)
            }
        }
        saveExercises()
        saveWorkouts()
    }

    @discardableResult
    func saveExercises() -> Bool {
        let ok = exerciseStore.saveExercises(globalExercises)
        if !ok {
            persistenceFailureReporter.report("Could not save exercises. Your last change may not persist after you quit the app.")
        }
        return ok
    }

    // MARK: - Local exercise display names

    func resolvedDisplayName(for exercise: Exercise) -> String {
        exerciseStore.resolvedDisplayName(for: exercise, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
    }

    func displayName(for snapshot: ExerciseSnapshot) -> String {
        exerciseStore.displayName(for: snapshot, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
    }

    func resolveExercise(for snapshot: ExerciseSnapshot) -> Exercise? {
        globalExercises.first { $0.id == snapshot.exerciseId }
    }

    func displayName(for we: WorkoutExercise) -> String {
        exerciseStore.displayName(for: we, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
    }

    func hasLocalDisplayName(for exerciseId: UUID) -> Bool {
        guard let s = exerciseLocalDisplayNames[exerciseId] else { return false }
        return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setLocalExerciseDisplayName(for exerciseId: UUID, customName: String?) {
        guard let ex = globalExercises.first(where: { $0.id == exerciseId }) else { return }
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var next = exerciseLocalDisplayNames
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare(ex.name) == .orderedSame {
            next.removeValue(forKey: exerciseId)
        } else {
            next[exerciseId] = trimmed
        }
        exerciseLocalDisplayNames = next
        saveExerciseLocalDisplayNames()
    }

    func clearLocalExerciseDisplayName(for exerciseId: UUID) {
        var next = exerciseLocalDisplayNames
        next.removeValue(forKey: exerciseId)
        exerciseLocalDisplayNames = next
        saveExerciseLocalDisplayNames()
    }

    private func saveExerciseLocalDisplayNames() {
        exerciseStore.saveDisplayNames(exerciseLocalDisplayNames)
    }

    // MARK: - Exercise library seeding

    private static let defaultExerciseNames: Set<String> = [
        "Barbell Bench Press", "Incline Barbell Bench Press", "Decline Barbell Bench Press",
        "Dumbbell Bench Press", "Incline Dumbbell Press", "Dumbbell Flies", "Cable Crossover",
        "Overhead Barbell Press", "Seated Dumbbell Press", "Arnold Press", "Lateral Raise",
        "Front Raise", "Rear Delt Fly", "Tricep Pushdown", "Overhead Tricep Extension",
        "Skull Crushers", "Close-Grip Bench Press", "Dips (Chest/Triceps)", "Pull-Up", "Chin-Up",
        "Lat Pulldown (Wide Grip)", "Lat Pulldown (Neutral Grip)", "Bent-Over Barbell Row",
        "Pendlay Row", "Seated Cable Row", "Single-Arm Dumbbell Row", "T-Bar Row", "Face Pull",
        "Deadlift (Conventional)", "Romanian Deadlift", "Barbell Shrug",
        "Back Squat (High Bar)", "Low-Bar Back Squat", "Front Squat", "Leg Press", "Hack Squat",
        "Bulgarian Split Squat", "Walking Lunges", "Leg Extension", "Lying Leg Curl",
        "Seated Leg Curl", "Standing Calf Raise", "Seated Calf Raise", "Barbell Bicep Curl",
        "EZ-Bar Curl", "Dumbbell Hammer Curl", "Concentration Curl", "Cable Bicep Curl",
        "Plank", "Hanging Leg Raise", "Ab Wheel Rollout", "Russian Twist", "Cable Crunch"
    ]

    private func migrateLegacyCustomExercises() {
        let builtInNames = Self.defaultExerciseNames.union(CardioExerciseSeed.builtInNames)
        var changed = false
        for i in globalExercises.indices {
            if !globalExercises[i].isCustom && !builtInNames.contains(globalExercises[i].name) {
                globalExercises[i].isCustom = true
                changed = true
            }
        }
        if changed { saveExercises() }
    }

    /// Idempotent merge of bundled cardio catalog by stable seed UUIDs.
    func preloadCardioExerciseLibraryIfNeeded() {
        let key = CardioExerciseSeed.completedUserDefaultsKey
        let alreadyDone = UserDefaults.standard.bool(forKey: key)
        let added = CardioExerciseSeed.merge(into: &globalExercises)
        if added {
            saveExercises()
        }
        if added || !alreadyDone {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func preloadFullExerciseLibrary() {
        typealias MG = MuscleGroup
        globalExercises = [
            Exercise(id: UUID(), name: "Barbell Bench Press", description: "Flat barbell bench press", targetedMuscles: [MG.chest, .triceps, .frontDelts]),
            Exercise(id: UUID(), name: "Incline Barbell Bench Press", description: "Incline barbell bench", targetedMuscles: [MG.upperChest, .triceps, .frontDelts]),
            Exercise(id: UUID(), name: "Decline Barbell Bench Press", description: "Decline barbell bench", targetedMuscles: [MG.lowerChest, .triceps]),
            Exercise(id: UUID(), name: "Dumbbell Bench Press", description: "Flat dumbbell press", targetedMuscles: [MG.chest, .triceps]),
            Exercise(id: UUID(), name: "Incline Dumbbell Press", description: "Incline dumbbell press", targetedMuscles: [MG.upperChest, .frontDelts]),
            Exercise(id: UUID(), name: "Dumbbell Flies", description: "Flat or incline flies", targetedMuscles: [MG.chest]),
            Exercise(id: UUID(), name: "Cable Crossover", description: "High-to-low cable fly", targetedMuscles: [MG.chest]),
            Exercise(id: UUID(), name: "Overhead Barbell Press", description: "Standing military press", targetedMuscles: [MG.frontDelts, .sideDelts, .triceps]),
            Exercise(id: UUID(), name: "Seated Dumbbell Press", description: "Seated overhead press", targetedMuscles: [MG.frontDelts, .sideDelts]),
            Exercise(id: UUID(), name: "Arnold Press", description: "Rotating dumbbell press", targetedMuscles: [MG.frontDelts, .sideDelts]),
            Exercise(id: UUID(), name: "Lateral Raise", description: "Dumbbell side lateral raise", targetedMuscles: [MG.sideDelts]),
            Exercise(id: UUID(), name: "Front Raise", description: "Dumbbell or plate front raise", targetedMuscles: [MG.frontDelts]),
            Exercise(id: UUID(), name: "Rear Delt Fly", description: "Dumbbell or machine rear delt fly", targetedMuscles: [MG.rearDelts]),
            Exercise(id: UUID(), name: "Tricep Pushdown", description: "Cable rope or bar pushdown", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Overhead Tricep Extension", description: "Cable or dumbbell overhead extension", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Skull Crushers", description: "EZ-bar lying tricep extension", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Close-Grip Bench Press", description: "Triceps-focused bench", targetedMuscles: [MG.triceps, .chest, .frontDelts]),
            Exercise(id: UUID(), name: "Dips (Chest/Triceps)", description: "Parallel bar dips", targetedMuscles: [MG.triceps, .chest, .frontDelts]),
            Exercise(id: UUID(), name: "Pull-Up", description: "Strict wide-grip pull-up", targetedMuscles: [MG.lats, .biceps, .rearDelts]),
            Exercise(id: UUID(), name: "Chin-Up", description: "Supinated grip chin-up", targetedMuscles: [MG.biceps, .lats]),
            Exercise(id: UUID(), name: "Lat Pulldown (Wide Grip)", description: "Wide-grip cable pulldown", targetedMuscles: [MG.lats]),
            Exercise(id: UUID(), name: "Lat Pulldown (Neutral Grip)", description: "Neutral or V-bar pulldown", targetedMuscles: [MG.lats, .biceps]),
            Exercise(id: UUID(), name: "Bent-Over Barbell Row", description: "Barbell back row", targetedMuscles: [MG.upperBack, .lats, .biceps]),
            Exercise(id: UUID(), name: "Pendlay Row", description: "Explosive barbell row from floor", targetedMuscles: [MG.upperBack, .lats]),
            Exercise(id: UUID(), name: "Seated Cable Row", description: "Mid-back cable row", targetedMuscles: [MG.midBack, .rhomboids]),
            Exercise(id: UUID(), name: "Single-Arm Dumbbell Row", description: "Supported DB row", targetedMuscles: [MG.lats, .upperBack]),
            Exercise(id: UUID(), name: "T-Bar Row", description: "Chest-supported or landmine T-bar", targetedMuscles: [MG.upperBack, .lats]),
            Exercise(id: UUID(), name: "Face Pull", description: "Cable rear delt / external rotation", targetedMuscles: [MG.rearDelts, .rotatorCuff, .traps]),
            Exercise(id: UUID(), name: "Deadlift (Conventional)", description: "Classic barbell deadlift", targetedMuscles: [MG.posteriorChain, .glutes, .lowerBack]),
            Exercise(id: UUID(), name: "Romanian Deadlift", description: "Hamstring-focused RDL", targetedMuscles: [MG.hamstrings, .glutes, .lowerBack]),
            Exercise(id: UUID(), name: "Barbell Shrug", description: "Trap shrug", targetedMuscles: [MG.traps]),
            Exercise(id: UUID(), name: "Back Squat (High Bar)", description: "High-bar barbell squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Low-Bar Back Squat", description: "Powerlifting-style squat", targetedMuscles: [MG.glutes, .quads, .hamstrings]),
            Exercise(id: UUID(), name: "Front Squat", description: "Barbell front squat", targetedMuscles: [MG.quads, .core]),
            Exercise(id: UUID(), name: "Leg Press", description: "45\u{00b0} or horizontal leg press", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Hack Squat", description: "Machine hack squat", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Bulgarian Split Squat", description: "Rear-foot-elevated split squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Walking Lunges", description: "Dumbbell walking lunges", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Leg Extension", description: "Quad isolation machine", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Lying Leg Curl", description: "Hamstring curl machine", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Seated Leg Curl", description: "Seated hamstring curl", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Standing Calf Raise", description: "Machine or smith standing calf", targetedMuscles: [MG.calves]),
            Exercise(id: UUID(), name: "Seated Calf Raise", description: "Seated calf machine", targetedMuscles: [MG.soleus]),
            Exercise(id: UUID(), name: "Barbell Bicep Curl", description: "Standing barbell curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "EZ-Bar Curl", description: "EZ-bar bicep curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Dumbbell Hammer Curl", description: "Neutral grip curl", targetedMuscles: [MG.brachialis, .biceps]),
            Exercise(id: UUID(), name: "Concentration Curl", description: "Seated DB concentration curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Cable Bicep Curl", description: "Low-cable bicep curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Plank", description: "Forearm plank hold", targetedMuscles: [MG.core]),
            Exercise(id: UUID(), name: "Hanging Leg Raise", description: "Strict hanging leg raise", targetedMuscles: [MG.lowerAbs]),
            Exercise(id: UUID(), name: "Ab Wheel Rollout", description: "Ab wheel from knees or standing", targetedMuscles: [MG.core]),
            Exercise(id: UUID(), name: "Russian Twist", description: "Weighted or bodyweight twist", targetedMuscles: [MG.obliques]),
            Exercise(id: UUID(), name: "Cable Crunch", description: "Kneeling cable crunch", targetedMuscles: [MG.abs])
        ]
        for index in globalExercises.indices {
            StrengthExerciseMetadataCatalog.apply(to: &globalExercises[index])
        }
        saveExercises()
    }

    private func backfillStrengthExerciseMetadataIfNeeded() {
        let key = "fitlog.strengthExerciseMetadataV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        var changed = false
        for index in globalExercises.indices {
            guard globalExercises[index].modality == .strength, !globalExercises[index].isCustom else { continue }
            let beforeRole = globalExercises[index].exerciseRole
            let beforePattern = globalExercises[index].movementPattern
            StrengthExerciseMetadataCatalog.apply(to: &globalExercises[index])
            if globalExercises[index].exerciseRole != beforeRole
                || globalExercises[index].movementPattern != beforePattern {
                changed = true
            }
        }
        if changed { saveExercises() }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Sessions

    func refreshCompletedSessions() {
        completedSessions = sessionStore.loadSessions()
        reconcileSkippedCycleTrainingDays()
    }

    func appendCompletedSession(_ session: WorkoutSession) {
        if let existingIndex = completedSessions.firstIndex(where: { $0.id == session.id }) {
            completedSessions[existingIndex] = session
        } else {
            completedSessions.append(session)
        }
        if !sessionStore.upsertSession(session) {
            persistenceFailureReporter.report("Could not save workout history. This session may be missing after you quit the app.")
        }
        reconcileSkippedCycleTrainingDays()
    }

    /// Template for a new live session from a **completed** session (library + flexible slots when possible).
    func workoutForNewSession(fromCompleted session: WorkoutSession) -> Workout {
        if let library = userWorkouts.first(where: { $0.id == session.workout.id }) {
            return library.hasFlexibleSlots ? sessionInstance(from: library) : library
        }
        return session.workout
    }

    /// Most recent completed session today for this library workout (plan ref or legacy same workout id).
    func mostRecentCompletedSessionToday(forLibraryWorkoutId libraryWorkoutId: UUID, referenceDate: Date = Date(), calendar: Calendar = .current) -> WorkoutSession? {
        let planRef = WorkoutPlanRef.workout(libraryWorkoutId)
        let candidates = completedSessions.filter { session in
            guard let end = session.endTime, calendar.isDate(end, inSameDayAs: referenceDate) else { return false }
            if session.sessionPlanOrigin == planRef { return true }
            if session.sessionPlanOrigin == nil, session.workout.id == libraryWorkoutId { return true }
            return false
        }
        return candidates.max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    /// Removes a completed session from history and persists. Returns false if save failed (state rolled back).
    @discardableResult
    func deleteCompletedSession(id: UUID) -> Bool {
        let previous = completedSessions
        completedSessions.removeAll { $0.id == id }
        guard sessionStore.saveSessions(completedSessions) else {
            completedSessions = previous
            return false
        }
        reconcileSkippedCycleTrainingDays()
        return true
    }

    /// Re-inserts a session removed by `deleteCompletedSession` (e.g. Undo).
    @discardableResult
    func restoreCompletedSession(_ session: WorkoutSession) -> Bool {
        guard !completedSessions.contains(where: { $0.id == session.id }) else { return true }
        var next = completedSessions
        next.append(session)
        next.sort { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
        let previous = completedSessions
        completedSessions = next
        guard sessionStore.saveSessions(completedSessions) else {
            completedSessions = previous
            return false
        }
        reconcileSkippedCycleTrainingDays()
        return true
    }

    @discardableResult
    func saveSessions() -> Bool {
        let ok = sessionStore.saveSessions(completedSessions)
        if ok {
            reconcileSkippedCycleTrainingDays()
        } else {
            persistenceFailureReporter.report("Could not save workout history.")
        }
        return ok
    }

    func syncSessionToHealthIfEnabled(_ session: WorkoutSession) {
        Task {
            await healthSyncService.writeWorkoutIfAuthorized(session: session, exercises: globalExercises)
            await MainActor.run {
                healthSyncStatusMessage = healthSyncService.statusMessage
            }
        }
    }

    // MARK: - Week summary / analytics

    var workoutsThisWeek: Int {
        let sevenDaysAgo = Date().addingTimeInterval(-7*24*60*60)
        return completedSessions.filter { ($0.endTime ?? Date()) > sevenDaysAgo }.count
    }

    /// Hard working sets in the last 72 hours and a typical 72h baseline for readiness scoring.
    func trainingLoadMetrics(now: Date = Date()) -> (recentHardSets: Int, typicalHardSets72h: Double) {
        let windowSeconds: TimeInterval = 72 * 60 * 60
        let baselineWindowSeconds: TimeInterval = 28 * 24 * 60 * 60
        let recentCutoff = now.addingTimeInterval(-windowSeconds)
        let baselineCutoff = now.addingTimeInterval(-baselineWindowSeconds)

        func hardSets(in session: WorkoutSession) -> Int {
            session.exerciseLogs.flatMap(\.loggedSets).filter { set in
                guard set.setType != .warmup else { return false }
                return set.reps > 0
            }.count
        }

        let recentHardSets = completedSessions
            .filter { ($0.endTime ?? .distantPast) >= recentCutoff }
            .reduce(0) { $0 + hardSets(in: $1) }

        let baselineSessions = completedSessions.filter { ($0.endTime ?? .distantPast) >= baselineCutoff }
        let totalBaselineHardSets = baselineSessions.reduce(0) { $0 + hardSets(in: $1) }
        let baselineDays = max(1.0, baselineWindowSeconds / (24 * 60 * 60))
        let dailyAverage = Double(totalBaselineHardSets) / baselineDays
        let typicalHardSets72h = max(6, dailyAverage * 3)

        return (recentHardSets, typicalHardSets72h)
    }

    struct WeekAtAGlance: Equatable {
        let isoWeekKey: String
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)]
        let completedCount: Int
        let weeklyGoal: Int?

        static func == (lhs: WeekAtAGlance, rhs: WeekAtAGlance) -> Bool {
            lhs.isoWeekKey == rhs.isoWeekKey
                && lhs.completedCount == rhs.completedCount
                && lhs.weeklyGoal == rhs.weeklyGoal
                && lhs.days.elementsEqual(rhs.days) { a, b in
                    a.date == b.date && a.weekday == b.weekday && a.hasWorkout == b.hasWorkout
                }
        }
    }

    func weekAtAGlance(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeekAtAGlance {
        let weekKey = TrainingProgramState.isoWeekKey(for: referenceDate, calendar: calendar)
        let dayStarts = TrainingProgramState.orderedCalendarDaysInWeek(containing: referenceDate, calendar: calendar)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)] = dayStarts.map { dayStart in
            let wd = calendar.component(.weekday, from: dayStart)
            let hasWorkout = completedSessions.contains { session in
                guard let end = session.endTime else { return false }
                return calendar.isDate(end, inSameDayAs: dayStart)
            }
            return (date: dayStart, weekday: wd, hasWorkout: hasWorkout)
        }
        let completed: Int
        if let weekInterval {
            completed = completedSessions.filter { session in
                guard let end = session.endTime else { return false }
                return end >= weekInterval.start && end < weekInterval.end
            }.count
        } else {
            completed = 0
        }
        let goal: Int? = trainingProgram.cycleEntries.isEmpty
            ? nil
            : min(max(1, trainingProgram.sessionsPerWeek), 7)
        return WeekAtAGlance(isoWeekKey: weekKey, days: days, completedCount: completed, weeklyGoal: goal)
    }

    /// Most recent completion date for sessions tied to a library workout id.
    func lastCompletedDate(forLibraryWorkoutId libraryId: UUID) -> Date? {
        completedSessions.compactMap { session -> Date? in
            guard let end = session.endTime else { return nil }
            if session.sessionPlanOrigin?.libraryWorkoutId == libraryId { return end }
            return nil
        }.max()
    }

    /// Unique library workout ids from recent completed sessions, most recent first.
    func recentCompletedLibraryWorkoutIds(limit: Int = 4) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        let sorted = completedSessions
            .filter { $0.isCompleted }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
        for session in sorted {
            guard let id = session.sessionPlanOrigin?.libraryWorkoutId else { continue }
            if seen.insert(id).inserted {
                result.append(id)
                if result.count >= limit { break }
            }
        }
        return result
    }

    /// ISO-week snapshot for the Home recap card (current vs prior week).
    struct WeeklyRecapSummary: Equatable {
        let isoWeekKey: String
        let sessionsThisWeek: Int
        let sessionsPriorWeek: Int
        /// Sum of `LoggedSet.totalVolumeLoad` (pounds × reps) for the week.
        let volumeThisWeekLbRep: Double
        let volumePriorWeekLbRep: Double
        let setsThisWeek: Int
        let weeklyGoal: Int?

        var metWeeklyGoal: Bool {
            guard let g = weeklyGoal else { return false }
            return sessionsThisWeek >= g
        }

        /// Show the celebration / summary card when the user actually trained this week.
        var shouldShowRecapCard: Bool { sessionsThisWeek > 0 }

        var volumeChangeFraction: Double? {
            guard volumePriorWeekLbRep > 1 else { return nil }
            return (volumeThisWeekLbRep - volumePriorWeekLbRep) / volumePriorWeekLbRep
        }
    }

    func weeklyRecapSummary(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeeklyRecapSummary? {
        let weekKey = TrainingProgramState.isoWeekKey(for: referenceDate, calendar: calendar)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return nil }

        let priorStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekInterval.start) ?? weekInterval.start
        let priorEnd = weekInterval.start

        func sessionsEnding(in range: Range<Date>) -> [WorkoutSession] {
            completedSessions.filter { session in
                guard let end = session.endTime else { return false }
                return end >= range.lowerBound && end < range.upperBound
            }
        }

        func aggregateVolumeAndSets(_ sessions: [WorkoutSession]) -> (volume: Double, sets: Int) {
            var vol = 0.0
            var setCount = 0
            for s in sessions {
                for log in s.exerciseLogs {
                    for st in log.loggedSets {
                        vol += st.totalVolumeLoad
                        setCount += 1
                    }
                }
            }
            return (vol, setCount)
        }

        let thisWeekSessions = sessionsEnding(in: weekInterval.start..<weekInterval.end)
        let priorWeekSessions = sessionsEnding(in: priorStart..<priorEnd)

        let thisAgg = aggregateVolumeAndSets(thisWeekSessions)
        let priorAgg = aggregateVolumeAndSets(priorWeekSessions)

        let goal: Int? = trainingProgram.cycleEntries.isEmpty
            ? nil
            : min(max(1, trainingProgram.sessionsPerWeek), 7)

        return WeeklyRecapSummary(
            isoWeekKey: weekKey,
            sessionsThisWeek: thisWeekSessions.count,
            sessionsPriorWeek: priorWeekSessions.count,
            volumeThisWeekLbRep: thisAgg.volume,
            volumePriorWeekLbRep: priorAgg.volume,
            setsThisWeek: thisAgg.sets,
            weeklyGoal: goal
        )
    }

    // MARK: - Exercise CRUD on workouts

    /// Removes a row and returns a snapshot for Undo. Returns `nil` if nothing was removed.
    @discardableResult
    func deleteExerciseReturningSnapshot(from workout: Workout, exerciseId: UUID) -> WorkoutExerciseDeletionSnapshot? {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return nil }
        guard let exIndex = userWorkouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else { return nil }
        let we = userWorkouts[wIndex].exercises[exIndex]
        let tid = userWorkouts[wIndex].templateSlotIdByWorkoutExerciseId[exerciseId]
        userWorkouts[wIndex].exercises.remove(at: exIndex)
        userWorkouts[wIndex].templateSlotIdByWorkoutExerciseId.removeValue(forKey: exerciseId)
        saveWorkouts()
        return WorkoutExerciseDeletionSnapshot(
            workoutId: workout.id,
            insertionIndex: exIndex,
            workoutExercise: we,
            templateSlotId: tid
        )
    }

    func restoreWorkoutExercise(_ snapshot: WorkoutExerciseDeletionSnapshot) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == snapshot.workoutId }) else { return }
        var w = userWorkouts[wIndex]
        guard !w.exercises.contains(where: { $0.id == snapshot.workoutExercise.id }) else { return }
        let i = min(snapshot.insertionIndex, w.exercises.count)
        w.exercises.insert(snapshot.workoutExercise, at: i)
        if let tid = snapshot.templateSlotId {
            w.templateSlotIdByWorkoutExerciseId[snapshot.workoutExercise.id] = tid
        }
        userWorkouts[wIndex] = w
        saveWorkouts()
    }

    func deleteExercise(from workout: Workout, exerciseId: UUID) {
        _ = deleteExerciseReturningSnapshot(from: workout, exerciseId: exerciseId)
    }

    func moveExercise(in workout: Workout, from source: IndexSet, to destination: Int) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        let count = userWorkouts[wIndex].exercises.count
        guard count > 0 else { return }

        let safeSource = IndexSet(source.filter { $0 >= 0 && $0 < count })
        guard !safeSource.isEmpty else { return }
        // SwiftUI `onMove` destinations can be unstable at boundaries (especially top insert).
        // Normalize to a legal insertion target and avoid no-op move traps.
        let safeDestination = min(max(0, destination), count)
        if safeSource.count == 1,
           let from = safeSource.first,
           (from == safeDestination || from + 1 == safeDestination) {
            return
        }

        userWorkouts[wIndex].exercises.move(fromOffsets: safeSource, toOffset: safeDestination)
        saveWorkouts()
    }

    @discardableResult
    func addExercise(
        to workout: Workout,
        exercise: Exercise,
        recommendedSets: Int,
        recommendedReps: String,
        configurationFields: [String],
        recommendedConfigBySet: [[String: String]]
    ) -> WorkoutExercise? {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return nil }
        let weId = UUID()
        let slotId = UUID()
        let blueprint = SlotBlueprint(
            id: slotId,
            label: exercise.name,
            targetedMuscles: exercise.targetedMuscles.isEmpty ? [.other] : exercise.targetedMuscles,
            exerciseRole: exercise.exerciseRole,
            movementPattern: exercise.movementPattern,
            defaultExerciseId: exercise.id,
            defaultRestTime: 90,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps
        )
        let we = WorkoutExercise(
            id: weId,
            resolution: .flexible(blueprint),
            defaultRestTime: 90,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            configurationFields: configurationFields,
            recommendedConfigBySet: recommendedConfigBySet
        )
        userWorkouts[index].exercises.append(we)
        userWorkouts[index].templateSlotIdByWorkoutExerciseId[weId] = slotId
        saveWorkouts()
        return we
    }

    @discardableResult
    func addCardioExercise(
        to workout: Workout,
        exercise: Exercise,
        prescription: CardioPrescription
    ) -> WorkoutExercise? {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return nil }
        let recommendedSets: Int = {
            switch prescription.kind {
            case .intervals:
                return max(1, prescription.intervals.reduce(0) { $0 + max(1, $1.repeatCount) })
            default:
                return 1
            }
        }()
        let recommendedReps: String = {
            switch prescription.kind {
            case .intervals: return "intervals"
            case .steadyState: return "steady"
            case .circuit: return "circuit"
            case .custom: return "cardio"
            }
        }()
        let weId = UUID()
        let slotId = UUID()
        let blueprint = SlotBlueprint(
            id: slotId,
            label: exercise.name,
            targetedMuscles: exercise.targetedMuscles.isEmpty ? [.other] : exercise.targetedMuscles,
            exerciseRole: exercise.exerciseRole,
            movementPattern: exercise.movementPattern,
            defaultExerciseId: exercise.id,
            defaultRestTime: 90,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            cardioPrescription: prescription
        )
        let we = WorkoutExercise(
            id: weId,
            resolution: .flexible(blueprint),
            defaultRestTime: 90,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            configurationFields: [],
            recommendedConfigBySet: [],
            cardioPrescription: prescription
        )
        userWorkouts[index].exercises.append(we)
        userWorkouts[index].templateSlotIdByWorkoutExerciseId[weId] = slotId
        saveWorkouts()
        return we
    }

    func updateCardioPrescription(
        workoutId: UUID,
        workoutExerciseId: UUID,
        prescription: CardioPrescription
    ) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workoutId }),
              let eIndex = userWorkouts[wIndex].exercises.firstIndex(where: { $0.id == workoutExerciseId })
        else { return }

        userWorkouts[wIndex].exercises[eIndex].cardioPrescription = prescription
        if case .flexible(var blueprint) = userWorkouts[wIndex].exercises[eIndex].resolution {
            blueprint.cardioPrescription = prescription
            userWorkouts[wIndex].exercises[eIndex].resolution = .flexible(blueprint)
        }

        switch prescription.kind {
        case .intervals:
            let count = max(1, prescription.intervals.reduce(0) { $0 + max(1, $1.repeatCount) })
            userWorkouts[wIndex].exercises[eIndex].recommendedSets = count
            userWorkouts[wIndex].exercises[eIndex].recommendedReps = "intervals"
        case .steadyState:
            userWorkouts[wIndex].exercises[eIndex].recommendedSets = 1
            userWorkouts[wIndex].exercises[eIndex].recommendedReps = "steady"
        case .circuit:
            userWorkouts[wIndex].exercises[eIndex].recommendedSets = 1
            userWorkouts[wIndex].exercises[eIndex].recommendedReps = "circuit"
        case .custom:
            userWorkouts[wIndex].exercises[eIndex].recommendedSets = 1
            userWorkouts[wIndex].exercises[eIndex].recommendedReps = "cardio"
        }

        saveWorkouts()
    }

    // MARK: - Training program

    func saveTrainingProgram() {
        if !programStore.saveProgram(trainingProgram) {
            persistenceFailureReporter.report("Could not save your training program.")
        }
    }

    /// Persists `dynamicProgramState` and syncs schedule + cycle (when materialized) into `trainingProgram`.
    func saveDynamicProgramState() {
        if let s = dynamicProgramState {
            if !dynamicProgramStore.saveActiveState(s) {
                persistenceFailureReporter.report("Could not save your program.")
            }
        } else {
            dynamicProgramStore.clearActiveState()
        }
        syncTrainingProgramFromDynamicProgram()
        if dynamicProgramState != nil {
            saveTrainingProgram()
        }
    }

    /// Replaces the active dynamic program (or clears when `nil`).
    func setDynamicProgramState(_ state: DynamicProgramState?) {
        lastNotifiedDynamicProgramId = nil
        lastNotifiedDynamicBlockId = nil
        dynamicProgramState = state
        saveDynamicProgramState()
    }

    /// Marks a calendar day as busy for the active dynamic program (compress / shift / flex policies).
    func setDynamicProgramBusyDay(dayKey: String, isBusy: Bool, calendar: Calendar = .current) {
        guard var dyn = dynamicProgramState else { return }
        let adapter = ScheduleAdaptationService(calendar: calendar)
        let engine = PeriodizationEngine(calendar: calendar)
        adapter.setBusyDay(dayKey: dayKey, isBusy: isBusy, state: &dyn)
        if isBusy, dyn.program.busyDayPolicy == .shift,
           let d = TrainingProgramState.date(fromDayKey: dayKey, calendar: calendar),
           let placement = engine.blockPlacement(on: d, state: dyn) {
            adapter.extendBlockShift(blockId: placement.block.id, additionalDays: 1, state: &dyn)
        }
        dynamicProgramState = dyn
        saveDynamicProgramState()
    }

    /// Updates the active dynamic program’s display name and persists.
    func updateDynamicProgramName(_ name: String) {
        guard var dyn = dynamicProgramState else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dyn.program.name = trimmed
        dynamicProgramState = dyn
        saveDynamicProgramState()
    }

    /// Updates sessions per week and preferred weekdays on the embedded `DynamicProgram`.
    func updateDynamicProgramSchedule(sessionsPerWeek: Int, preferredWeekdays: [Int]) {
        guard var dyn = dynamicProgramState else { return }
        dyn.program.defaultSessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        dyn.program.preferredWeekdays = preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        dynamicProgramState = dyn
        saveDynamicProgramState()
    }

    /// Updates busy-day policy on the active dynamic program.
    func updateDynamicProgramBusyDayPolicy(_ policy: BusyDayPolicy) {
        guard var dyn = dynamicProgramState else { return }
        dyn.program.busyDayPolicy = policy
        dynamicProgramState = dyn
        saveDynamicProgramState()
    }

    /// Updates the program timeline anchor (start of program in calendar terms).
    func updateDynamicProgramAnchorDate(_ date: Date, calendar: Calendar = .current) {
        guard var dyn = dynamicProgramState else { return }
        dyn.anchorDate = calendar.startOfDay(for: date)
        dynamicProgramState = dyn
        saveDynamicProgramState()
    }

    /// Copies `DynamicProgram` schedule and optional materialized cycle into `trainingProgram`.
    private func syncTrainingProgramFromDynamicProgram(calendar: Calendar = .current) {
        guard let s = dynamicProgramState else { return }
        var p = trainingProgram
        p.sessionsPerWeek = s.program.defaultSessionsPerWeek
        p.preferredWeekdays = s.program.preferredWeekdays
        p.anchorDayKey = TrainingProgramState.dayKey(for: s.anchorDate, calendar: calendar)
        p.skippedCycleTrainingDayKeys = s.skippedProgramTrainingDayKeys.sorted()

        let engine = PeriodizationEngine(calendar: calendar)
        if let placement = engine.blockPlacement(on: Date(), state: s) {
            let templates = placement.block.weeklyTemplates
            let refs: [WorkoutPlanRef] = templates.compactMap { t in
                guard let wid = s.materializedTemplateWorkoutIds[t.id] else { return nil }
                return .workout(wid)
            }
            if !templates.isEmpty, refs.count == templates.count {
                p.cycleEntries = refs
                p.cyclePhaseOffset = 0
            }
        }
        // When today falls before the anchor or after the program end, `blockPlacement` is nil and
        // cycle entries would otherwise stay empty while the calendar still resolves from `dynamicProgramState`.
        if p.cycleEntries.isEmpty, !s.program.blocks.isEmpty {
            let anchorStart = calendar.startOfDay(for: s.anchorDate)
            let todayStart = calendar.startOfDay(for: Date())
            let fallbackBlock: ProgramBlock
            if todayStart < anchorStart {
                fallbackBlock = s.program.blocks[0]
            } else {
                fallbackBlock = s.program.blocks[s.program.blocks.count - 1]
            }
            let templates = fallbackBlock.weeklyTemplates
            let refs: [WorkoutPlanRef] = templates.compactMap { t in
                guard let wid = s.materializedTemplateWorkoutIds[t.id] else { return nil }
                return .workout(wid)
            }
            if !templates.isEmpty, refs.count == templates.count {
                p.cycleEntries = refs
                p.cyclePhaseOffset = 0
            }
        }
        if !p.cycleEntries.isEmpty {
            normalizeCycleDerivedFields(&p)
        } else {
            p.cyclePhaseOffset = 0
        }
        applyTrainingProgramAfterFreezingPast(p)
    }

    /// Writes `dynamicProgramState` to SwiftData without re-running `syncTrainingProgramFromDynamicProgram` (avoids re-entrancy when caller already synced).
    private func saveDynamicProgramStateBlobOnly() {
        if let s = dynamicProgramState {
            dynamicProgramStore.saveActiveState(s)
        } else {
            dynamicProgramStore.clearActiveState()
        }
    }

    /// One line for AI split builder / Coach prefill from the current training program.
    func planCycleContextLineForCoach() -> String {
        let p = trainingProgram
        guard !p.cycleEntries.isEmpty else {
            return "No workout rotation configured yet. Sessions per week: \(p.sessionsPerWeek)."
        }
        let names = p.cycleEntries.map { planLabel(for: $0) }.joined(separator: " → ")
        let pool: String
        if p.preferredWeekdays.isEmpty {
            pool = "training day pool Mon–Fri (default)"
        } else {
            pool = "preferred weekdays: \(p.preferredWeekdays.sorted().map(String.init).joined(separator: ", "))"
        }
        return "Current rotation: \(names). Pattern: \(p.sessionsPerWeek)×/week, \(pool). Anchor: \(p.anchorDayKey)."
    }

    func applyTrainingProgramSuggestion(
        cycleWorkoutIds: [UUID],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        applyTrainingProgramSuggestion(
            cycleEntries: cycleWorkoutIds.map { .workout($0) },
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            anchorDate: anchorDate
        )
    }

    func applyTrainingProgramSuggestion(
        cycleEntries: [WorkoutPlanRef],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        var p = trainingProgram
        p.cycleEntries = cycleEntries
        p.sessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        p.preferredWeekdays = preferredWeekdays
        p.anchorDayKey = TrainingProgramState.dayKey(for: anchorDate)
        p.cyclePhaseOffset = 0
        p.skippedCycleTrainingDayKeys = []
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingCycleWorkoutIds(_ ids: [UUID]) {
        setTrainingCycleEntries(ids.map { .workout($0) })
    }

    func setTrainingCycleEntries(_ entries: [WorkoutPlanRef]) {
        var p = trainingProgram
        p.cycleEntries = entries
        normalizeCycleDerivedFields(&p)
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingSessionsPerWeek(_ n: Int) {
        var p = trainingProgram
        p.sessionsPerWeek = min(max(1, n), 7)
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingPreferredWeekdays(_ days: [Int]) {
        var p = trainingProgram
        p.preferredWeekdays = days
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingAnchorDate(_ date: Date) {
        var p = trainingProgram
        p.anchorDayKey = TrainingProgramState.dayKey(for: date)
        normalizeCycleDerivedFields(&p)
        applyTrainingProgramAfterFreezingPast(p)
    }

    /// Sets the rotation anchor to this calendar day and phase so the chosen workout is “day 1” of the cycle for future default assignments.
    func realignTrainingCycleAnchor(to date: Date, for ref: WorkoutPlanRef, calendar: Calendar = .current) {
        guard let idx = trainingProgram.cycleEntries.firstIndex(of: ref) else { return }
        var p = trainingProgram
        p.anchorDayKey = TrainingProgramState.dayKey(for: date, calendar: calendar)
        p.cyclePhaseOffset = idx
        normalizeCycleDerivedFields(&p)
        applyTrainingProgramAfterFreezingPast(p)
    }

    private func normalizeCycleDerivedFields(_ p: inout TrainingProgramState) {
        let n = p.cycleEntries.count
        if n == 0 {
            p.cyclePhaseOffset = 0
            p.skippedCycleTrainingDayKeys = []
            return
        }
        p.cyclePhaseOffset = ((p.cyclePhaseOffset % n) + n) % n
    }

    /// Missed planned workouts still outstanding in rotation order (oldest first).
    struct OutstandingMissedMakeup: Equatable, Identifiable, Sendable {
        let dayKey: String
        let missedDate: Date
        let planRef: WorkoutPlanRef
        let workout: Workout
        let templateLabel: String

        var id: String { dayKey }
    }

    /// Planned workouts the user missed that have not yet been credited (including via off-day makeup).
    func outstandingMissedMakeups(calendar: Calendar = .current, limit: Int = .max) -> [OutstandingMissedMakeup] {
        guard let dyn = dynamicProgramState, limit > 0 else { return [] }
        let cal = calendar
        let pe = PeriodizationEngine(calendar: cal)
        var results: [OutstandingMissedMakeup] = []

        for dayKey in dyn.skippedProgramTrainingDayKeys.sorted() {
            if results.count >= limit { break }
            guard let date = TrainingProgramState.date(fromDayKey: dayKey, calendar: cal) else { continue }
            var probe = dyn
            probe.skippedProgramTrainingDayKeys.remove(dayKey)
            let resolved = pe.resolvedTemplateDay(on: date, state: probe)
            let template: BlockWeeklyTemplate?
            switch resolved {
            case .training(let t), .flex(let t):
                template = t
            case .rest, .unscheduled:
                template = nil
            }
            guard let template,
                  let workoutId = dyn.materializedTemplateWorkoutIds[template.id],
                  let workout = userWorkouts.first(where: { $0.id == workoutId })
            else { continue }
            results.append(OutstandingMissedMakeup(
                dayKey: dayKey,
                missedDate: date,
                planRef: .workout(workoutId),
                workout: workout,
                templateLabel: template.dayName
            ))
        }
        return results
    }

    /// Marks past days where a workout was planned but nothing was logged so the rotation does not stay stuck on missed sessions.
    func reconcileSkippedCycleTrainingDays(calendar: Calendar = .current) {
        let cal = calendar
        if var dyn = dynamicProgramState {
            let adapter = ScheduleAdaptationService(calendar: cal)
            let engine = PeriodizationEngine(calendar: cal)
            let todayStart = cal.startOfDay(for: Date())
            let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart)

            let oldMissed = dyn.missedSessionDayKeys
            if let y = yesterday {
                adapter.mergeDetectedMisses(through: y, state: &dyn, completedSessions: completedSessions)
            }
            let newMisses = dyn.missedSessionDayKeys.subtracting(oldMissed)
            if dyn.program.busyDayPolicy == .shift {
                for key in newMisses {
                    if let d = TrainingProgramState.date(fromDayKey: key, calendar: cal),
                       let placement = engine.blockPlacement(on: d, state: dyn) {
                        adapter.extendBlockShift(blockId: placement.block.id, additionalDays: 1, state: &dyn)
                    }
                }
            }

            if let placement = engine.blockPlacement(on: todayStart, state: dyn), placement.index > 0 {
                for i in 0 ..< placement.index {
                    dyn.completedBlockIds.insert(dyn.program.blocks[i].id)
                }
            }

            adapter.mergeSkippedRotationKeysThroughYesterday(
                state: &dyn,
                completedSessions: completedSessions,
                dayOverrides: trainingProgram.dayOverrides,
                weekOverrides: trainingProgram.weekOverrides,
                frozenCalendarDays: trainingProgram.frozenCalendarDays
            )
            dynamicProgramState = dyn
            syncTrainingProgramFromDynamicProgram(calendar: cal)
            saveTrainingProgram()
            saveDynamicProgramStateBlobOnly()
            postDynamicProgramBlockTransitionIfNeeded(engine: engine, state: dyn, calendar: cal)
            return
        }
        guard !trainingProgram.cycleEntries.isEmpty else {
            if !trainingProgram.skippedCycleTrainingDayKeys.isEmpty {
                var p = trainingProgram
                p.skippedCycleTrainingDayKeys = []
                trainingProgram = p
                saveTrainingProgram()
            }
            return
        }

        // Legacy (non-dynamic) programs: same-calendar-day completion only; no off-day makeup crediting.
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }

        var walkStart: Date
        if let oldest = completedSessions.filter(\.isCompleted).map({ cal.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            walkStart = oldest
        } else if let fallback = cal.date(byAdding: .day, value: -14, to: todayStart) {
            walkStart = fallback
        } else {
            walkStart = yesterday
        }

        var newSkips = Set(trainingProgram.skippedCycleTrainingDayKeys)
        var walk = walkStart
        if walk > yesterday { return }

        while walk <= yesterday {
            let dk = TrainingProgramState.dayKey(for: walk, calendar: cal)
            let planned = resolvedScheduleDay(for: walk, calendar: cal)
            let done = primaryCompletedSession(on: walk, calendar: cal) != nil
            switch planned {
            case .workout:
                if done {
                    newSkips.remove(dk)
                } else {
                    newSkips.insert(dk)
                }
            case .rest, .unscheduled:
                newSkips.remove(dk)
            }
            guard let nx = cal.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = nx
        }

        let newArr = newSkips.sorted()
        if newSkips != Set(trainingProgram.skippedCycleTrainingDayKeys) {
            var p = trainingProgram
            p.skippedCycleTrainingDayKeys = newArr
            trainingProgram = p
            saveTrainingProgram()
        }
    }

    func clearTrainingDayOverride(dayKey: String) {
        var p = trainingProgram
        p.dayOverrides.removeValue(forKey: dayKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingDayOverride(dayKey: String, intent: ScheduleDayIntent, planRef: WorkoutPlanRef? = nil) {
        var p = trainingProgram
        p.dayOverrides[dayKey] = ScheduleDayOverride(intent: intent, planRef: planRef)
        trainingProgram = p
        saveTrainingProgram()
    }

    func clearWeekOverride(weekKey: String) {
        var p = trainingProgram
        p.weekOverrides.removeValue(forKey: weekKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setWeekDayOverride(weekKey: String, weekday: Int, intent: ScheduleDayIntent, planRef: WorkoutPlanRef? = nil) {
        var p = trainingProgram
        var w = p.weekOverrides[weekKey] ?? ScheduleWeekOverride()
        if intent == .inherit {
            w.weekdayOverrides.removeValue(forKey: String(weekday))
        } else {
            w.weekdayOverrides[String(weekday)] = ScheduleDayOverride(intent: intent, planRef: planRef)
        }
        if w.weekdayOverrides.isEmpty {
            p.weekOverrides.removeValue(forKey: weekKey)
        } else {
            p.weekOverrides[weekKey] = w
        }
        trainingProgram = p
        saveTrainingProgram()
    }

    func workoutDisplayName(forWorkoutId id: UUID) -> String {
        userWorkouts.first(where: { $0.id == id })?.name ?? "Missing workout"
    }

    // MARK: - Integrations / data transfer

    @MainActor
    func setHealthSyncEnabled(_ enabled: Bool) {
        Task { @MainActor in
            let granted = await healthSyncService.setSyncEnabled(enabled)
            healthSyncEnabled = granted
            healthSyncStatusMessage = healthSyncService.statusMessage
        }
    }

    func backupSnapshot() -> BackupSnapshot {
        BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: globalExercises,
            workouts: userWorkouts,
            sessions: completedSessions,
            program: trainingProgram,
            displayNames: exerciseLocalDisplayNames,
            dynamicProgram: dynamicProgramState,
            splitPresets: MigrationSnapshotExtras.splitPresets(from: splitPresetStore.loadPresets()),
            personalRecords: prStore.loadAllForBackup()
        )
    }

    func overwriteWithImportedSnapshot(_ snapshot: BackupSnapshot) {
        globalExercises = snapshot.exercises
        userWorkouts = snapshot.workouts
        completedSessions = snapshot.sessions
        trainingProgram = snapshot.program
        exerciseLocalDisplayNames = Dictionary(
            uniqueKeysWithValues: snapshot.displayNames.compactMap { key, value in
                guard let id = UUID(uuidString: key) else { return nil }
                return (id, value)
            }
        )

        if let dyn = snapshot.dynamicProgram {
            dynamicProgramState = dyn
            dynamicProgramStore.saveActiveState(dyn)
            syncTrainingProgramFromDynamicProgram()
        } else {
            dynamicProgramState = nil
            dynamicProgramStore.clearActiveState()
        }

        saveExercises()
        saveWorkouts()
        saveSessions()
        saveTrainingProgram()
        saveExerciseLocalDisplayNames()
        splitPresetStore.replaceAllFromBackup(snapshot.splitPresets)
        prStore.replaceAllFromBackup(snapshot.personalRecords)
        reconcileSkippedCycleTrainingDays()
        publishIntentExerciseLibrary()
    }

    /// Publishes exercise names for App Intents / Shortcuts entity queries.
    func publishIntentExerciseLibrary() {
        let entries = globalExercises.map {
            FitLogIntentBridge.ExerciseSnapshotEntry(id: $0.id, name: resolvedDisplayName(for: $0))
        }
        FitLogIntentBridge.publishExerciseLibrary(entries)
    }

    /// Recomputes PR rows for one exercise after set delete/edit in an active or completed session.
    func reconcilePersonalRecords(forExerciseId exerciseId: UUID, activeSession: WorkoutSession?) {
        var tuples: [(set: LoggedSet, sessionId: UUID)] = []
        for session in completedSessions {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                for set in log.loggedSets {
                    tuples.append((set, session.id))
                }
            }
        }
        if let activeSession {
            for log in activeSession.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                for set in log.loggedSets {
                    tuples.append((set, activeSession.id))
                }
            }
        }
        let name = globalExercises.first(where: { $0.id == exerciseId })?.name ?? "Exercise"
        prStore.reconcileBests(forExerciseId: exerciseId, fromSets: tuples, exerciseName: name)
    }

    @discardableResult
    func saveSplitPreset(
        name: String,
        days: [SplitBuilderEditableDay],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        notes: String = ""
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !days.isEmpty else { return false }
        _ = splitPresetStore.savePreset(
            name: trimmed,
            notes: notes,
            sessionsPerWeek: min(max(1, sessionsPerWeek), 7),
            preferredWeekdays: preferredWeekdays.filter { (1...7).contains($0) }.sorted(),
            days: days
        )
        return true
    }

    /// Deletes all locally stored user data while keeping the app usable (seeded exercise library remains).
    /// Does not remove workouts previously written to Apple Health — users manage those in the Health app.
    func eraseAllAppData() {
        rotateBackup()
        globalExercises = []
        userWorkouts = []
        completedSessions = []
        exerciseLocalDisplayNames = [:]
        trainingProgram = TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))
        dynamicProgramState = nil
        bodyMetricEntries = []
        progressPhotoRecords = []
        lastNotifiedDynamicProgramId = nil
        lastNotifiedDynamicBlockId = nil

        _ = exerciseStore.saveExercises([])
        _ = workoutStore.saveWorkouts([])
        _ = sessionStore.saveSessions([])
        _ = programStore.saveProgram(trainingProgram)
        dynamicProgramStore.clearActiveState()
        splitPresetStore.replaceAllFromBackup([])
        prStore.replaceAllFromBackup([])
        sessionStore.clearActiveSession()
        coachChatStore.deleteAllConversations()
        try? readinessStore.deleteAllSnapshots()
        bodyMetricsStore.eraseAll()
        CardioSessionTimerPersistence.clear()
        WidgetSnapshotStore.clear()
        Self.clearActiveWorkoutSessionUserDefaults()

        preloadFullExerciseLibrary()
        preloadCardioExerciseLibraryIfNeeded()
        publishIntentExerciseLibrary()
    }

    private static func clearActiveWorkoutSessionUserDefaults() {
        let defaults = UserDefaults.standard
        for key in [
            "activeWorkoutSession",
            "activeWorkoutTimerTotalPaused",
            "activeWorkoutTimerIsPaused",
            "activeWorkoutTimerPausedAt",
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    private func postDynamicProgramBlockTransitionIfNeeded(
        engine: PeriodizationEngine,
        state: DynamicProgramState,
        calendar: Calendar
    ) {
        guard state.program.blocks.count > 1 else { return }
        let todayStart = calendar.startOfDay(for: Date())
        guard let placement = engine.blockPlacement(on: todayStart, state: state) else { return }
        if lastNotifiedDynamicProgramId != state.program.id {
            lastNotifiedDynamicProgramId = state.program.id
            lastNotifiedDynamicBlockId = placement.block.id
            return
        }
        if let prev = lastNotifiedDynamicBlockId, prev != placement.block.id {
            lastNotifiedDynamicBlockId = placement.block.id
            NotificationCenter.default.post(
                name: .fitlogDynamicProgramBlockChanged,
                object: nil,
                userInfo: [
                    "newBlockName": placement.block.name,
                    "newBlockIndex": placement.index + 1,
                    "blockCount": state.program.blocks.count,
                ]
            )
        } else if lastNotifiedDynamicBlockId == nil {
            lastNotifiedDynamicBlockId = placement.block.id
        }
    }

    // MARK: - Body metrics & progress photos

    private func reloadBodyAndPhotosFromDisk() {
        bodyMetricEntries = bodyMetricsStore.loadMetrics()
        progressPhotoRecords = bodyMetricsStore.loadPhotoRecords()
    }

    func upsertBodyMetric(_ entry: BodyMetricEntry) {
        var list = bodyMetricEntries.filter { $0.id != entry.id }
        list.append(entry)
        bodyMetricEntries = list.sorted { $0.date > $1.date }
        bodyMetricsStore.saveMetrics(bodyMetricEntries)
    }

    func deleteBodyMetric(id: UUID) {
        bodyMetricEntries.removeAll { $0.id == id }
        bodyMetricsStore.saveMetrics(bodyMetricEntries)
    }

    func addProgressPhoto(imageData: Data, capturedAt: Date) throws {
        let id = UUID()
        let fileName = try bodyMetricsStore.savePhotoFile(id: id, imageData: imageData)
        var rec = progressPhotoRecords
        rec.append(ProgressPhotoRecord(id: id, capturedAt: capturedAt, fileName: fileName))
        progressPhotoRecords = rec.sorted { $0.capturedAt > $1.capturedAt }
        bodyMetricsStore.savePhotoRecords(progressPhotoRecords)
    }

    func deleteProgressPhoto(id: UUID) {
        guard let idx = progressPhotoRecords.firstIndex(where: { $0.id == id }) else { return }
        bodyMetricsStore.deletePhotoFile(fileName: progressPhotoRecords[idx].fileName)
        progressPhotoRecords.remove(at: idx)
        bodyMetricsStore.savePhotoRecords(progressPhotoRecords)
    }

    func progressPhotoImageData(fileName: String) -> Data? {
        try? Data(contentsOf: bodyMetricsStore.photoFileURL(fileName: fileName))
    }
}
