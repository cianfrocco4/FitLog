//
//  CurrentWorkoutSessionViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import UserNotifications
import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif

/// When opening the pull-up sheet from elsewhere (e.g. workout plan), expand this row and optionally present the log-set sheet.
struct PendingPullUpFocus: Equatable {
    let exerciseLogIndex: Int
    let presentLogSetSheet: Bool
}

private enum PersistenceKey {
    static let activeSession = "activeWorkoutSession"
    static let timerTotalPaused = "activeWorkoutTimerTotalPaused"
    static let timerIsPaused = "activeWorkoutTimerIsPaused"
    static let timerPausedAt = "activeWorkoutTimerPausedAt"
}

/// Isolated 1 Hz clock so timer-display views observe only elapsed seconds
/// without subscribing to the full session view-model.
@Observable @MainActor
final class WorkoutTimerClock {
    var elapsedSeconds: Int = 0
}

@Observable @MainActor
final class CurrentWorkoutSessionViewModel {
    /// Injected at init; non-optional because the session VM requires it to persist sessions.
    var dataManager: DataManager

    var currentSession: WorkoutSession?
    var remainingRestTime: Int = 0
    /// Total seconds when the current rest countdown started (for UI progress rings). 0 when idle.
    var restCountdownTotalSeconds: Int = 0
    /// Set to true when a rest countdown naturally reaches zero (not when cancelled).
    var showRestCompleteAlert: Bool = false
    /// Cleared when consumed by `CurrentWorkoutPullUpSheet` on appear.
    var pendingPullUpFocus: PendingPullUpFocus?
    /// Set when a new personal record is detected while logging a set.
    var recentPersonalRecordEvent: PersonalRecordEvent?
    /// Populated when a workout is finished; consume to show the completion summary sheet.
    var pendingWorkoutCompletionSummary: WorkoutCompletionSummary?

    /// Granular timer clock — views that only need elapsed time observe this instead of the full VM.
    let clock = WorkoutTimerClock()

    /// Elapsed workout time in seconds (excluding paused time). Forwards to the clock.
    var workoutElapsedSeconds: Int {
        get { clock.elapsedSeconds }
        set { clock.elapsedSeconds = newValue }
    }
    
    private var restTimer: Timer?
    private var workoutTimer: Timer?
    private var backgroundDate: Date?
    private var wasTimerRunning = false
    
    /// Total time the workout has been paused (accumulated).
    private var totalPausedDuration: TimeInterval = 0
    /// When the user tapped Pause (nil when running).
    private var workoutPausedAt: Date?
    /// Tracks the most recent user activity within an active workout (logging sets, pausing, etc.).
    private var lastActivityDate: Date?
    /// Identifier for the pending \"workout still active\" reminder notification, so it can be rescheduled.
    private var inactivityNotificationIdentifier: String?

    /// Fixed id so the scheduled \"rest over\" notification can be cancelled when the user skips rest or ends the workout.
    private static let restCompleteNotificationIdentifier = "com.fitlog.restTimer.complete"
    
    var isInProgress: Bool { currentSession != nil && currentSession?.endTime == nil }
    var isWorkoutPaused: Bool { workoutPausedAt != nil }
    
    /// ID of the primary \"current\" exercise (first in the active list), if any.
    var primaryActiveExerciseId: UUID? {
        currentSession?.activeExerciseIds.first
    }
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        restoreActiveSessionIfNeeded()
    }
    
    func startWorkout(_ workout: Workout, sessionPlanOrigin: WorkoutPlanRef? = nil) {
        let logs = workout.exercises.map { ex in
            ExerciseLog(id: UUID(), workoutExercise: ex, loggedSets: [])
        }
        var session = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date(),
            endTime: nil,
            exerciseLogs: logs,
            sessionPlanOrigin: sessionPlanOrigin
        )
        if let firstId = workout.exercises.first?.exerciseId {
            session.activeExerciseIds = [firstId]
        }
        session.completedExerciseIds = []
        beginInProgressSession(session)
    }

    private func beginInProgressSession(_ session: WorkoutSession) {
        currentSession = session
        totalPausedDuration = 0
        workoutPausedAt = nil
        recordWorkoutActivity()
        saveActiveSession()
        saveTimerState()
        startWorkoutTimer()
        updateWorkoutElapsed()
    }
    
    /// - Parameter showCompletionSummary: When true (e.g. user tapped Finish in the workout sheet), publishes `pendingWorkoutCompletionSummary` for the post-workout screen.
    func stopWorkout(showCompletionSummary: Bool = false) {
        guard var session = currentSession else { return }

        normalizeConcreteSnapshotsOnExerciseLogs(&session.exerciseLogs)

        session.endTime = Date()

        let summary: WorkoutCompletionSummary? = showCompletionSummary
            ? dataManager.buildWorkoutCompletionSummary(
                session: session,
                activeElapsedSeconds: workoutElapsedSeconds
            )
            : nil

        dataManager.appendCompletedSession(session)
        dataManager.syncSessionToHealthIfEnabled(session)

        workoutTimer?.invalidate()
        workoutTimer = nil
        cancelRestTimer()
        currentSession = nil
        recentPersonalRecordEvent = nil
        workoutElapsedSeconds = 0
        clearInactivityReminder()
        clearPersistedActiveSession()
        pendingWorkoutCompletionSummary = summary
    }

    private func normalizeConcreteSnapshotsOnExerciseLogs(_ logs: inout [ExerciseLog]) {
        for i in logs.indices {
            var we = logs[i].workoutExercise
            guard !we.isSlotPlaceholder else { continue }
            if we.snapshot != nil { continue }
            guard let eid = we.exerciseId,
                  let ex = dataManager.globalExercises.first(where: { $0.id == eid })
            else { continue }
            we.resolution = .concrete(ExerciseSnapshot(from: ex))
            logs[i].workoutExercise = we
        }
    }

    /// Drops the in-progress workout without writing to history or HealthKit.
    func cancelWorkout() {
        guard currentSession != nil else { return }

        workoutTimer?.invalidate()
        workoutTimer = nil
        cancelRestTimer()
        currentSession = nil
        recentPersonalRecordEvent = nil
        workoutElapsedSeconds = 0
        totalPausedDuration = 0
        workoutPausedAt = nil
        clearInactivityReminder()
        clearPersistedActiveSession()
    }
    
    func pauseWorkout() {
        guard currentSession != nil, workoutPausedAt == nil else { return }
        workoutPausedAt = Date()
        recordWorkoutActivity()
        saveTimerState()
        saveActiveSession()
        workoutTimer?.invalidate()
        workoutTimer = nil
        updateWorkoutElapsed()
    }
    
    func resumeWorkout() {
        guard let pausedAt = workoutPausedAt else { return }
        totalPausedDuration += Date().timeIntervalSince(pausedAt)
        workoutPausedAt = nil
        recordWorkoutActivity()
        saveTimerState()
        saveActiveSession()
        startWorkoutTimer()
        updateWorkoutElapsed()
    }
    
    /// Formatted elapsed time for display (e.g. "12:34" or "1:05:22").
    var workoutElapsedFormatted: String {
        let total = workoutElapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    private func computedElapsedSeconds() -> Int {
        guard let session = currentSession else { return 0 }
        let start = session.startTime.timeIntervalSince1970
        let now: TimeInterval
        if let pausedAt = workoutPausedAt {
            now = pausedAt.timeIntervalSince1970
        } else {
            now = Date().timeIntervalSince1970
        }
        return max(0, Int(now - start - totalPausedDuration))
    }
    
    private func updateWorkoutElapsed() {
        clock.elapsedSeconds = computedElapsedSeconds()
    }

    private func startWorkoutTimer() {
        guard currentSession != nil, workoutPausedAt == nil else { return }
        workoutTimer?.invalidate()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateWorkoutElapsed() }
        }
        RunLoop.main.add(workoutTimer!, forMode: .common)
    }
    
    // MARK: - Persistence (background / restart)

    /// Persist the active session to SwiftData so it survives app kills.
    private func saveActiveSession() {
        guard let session = currentSession, session.endTime == nil else { return }
        dataManager.sessionStore.upsertActiveSession(session)
        saveTimerState()
    }

    private func saveTimerState() {
        UserDefaults.standard.set(totalPausedDuration, forKey: PersistenceKey.timerTotalPaused)
        UserDefaults.standard.set(workoutPausedAt != nil, forKey: PersistenceKey.timerIsPaused)
        UserDefaults.standard.set(workoutPausedAt?.timeIntervalSince1970, forKey: PersistenceKey.timerPausedAt)
    }

    private func clearPersistedActiveSession() {
        dataManager.sessionStore.clearActiveSession()
        UserDefaults.standard.removeObject(forKey: PersistenceKey.activeSession)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerTotalPaused)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerIsPaused)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerPausedAt)
    }

    private func restoreActiveSessionIfNeeded() {
        // Primary: SwiftData (survives hard app kills and schema migrations)
        if let session = dataManager.sessionStore.loadActiveSession(), session.endTime == nil {
            currentSession = session
            totalPausedDuration = UserDefaults.standard.double(forKey: PersistenceKey.timerTotalPaused)
            let wasPaused = UserDefaults.standard.bool(forKey: PersistenceKey.timerIsPaused)
            let pausedAtInterval = UserDefaults.standard.object(forKey: PersistenceKey.timerPausedAt) as? Double
            workoutPausedAt = wasPaused && pausedAtInterval != nil ? Date(timeIntervalSince1970: pausedAtInterval!) : nil
            updateWorkoutElapsed()
            if workoutPausedAt == nil { startWorkoutTimer() }
            return
        }
        // Migration path: legacy UserDefaults JSON (users upgrading from pre-Phase B builds)
        guard let data = UserDefaults.standard.data(forKey: PersistenceKey.activeSession),
              let session = try? JSONDecoder().decode(WorkoutSession.self, from: data),
              session.endTime == nil else {
            return
        }
        currentSession = session
        totalPausedDuration = UserDefaults.standard.double(forKey: PersistenceKey.timerTotalPaused)
        let wasPaused = UserDefaults.standard.bool(forKey: PersistenceKey.timerIsPaused)
        let pausedAtInterval = UserDefaults.standard.object(forKey: PersistenceKey.timerPausedAt) as? Double
        workoutPausedAt = wasPaused && pausedAtInterval != nil ? Date(timeIntervalSince1970: pausedAtInterval!) : nil
        // Immediately promote the legacy session into SwiftData so subsequent saves use the new path
        dataManager.sessionStore.upsertActiveSession(session)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.activeSession)
        updateWorkoutElapsed()
        if workoutPausedAt == nil { startWorkoutTimer() }
    }

    /// Sync the current session's workout and exercise logs with an updated workout definition.
    /// This ensures that exercises added to a workout while a session is in progress
    /// appear in the current session (with empty logs initially).
    func syncExercises(withUpdatedWorkout workout: Workout) {
        guard var session = currentSession, session.workout.id == workout.id else { return }

        // Update the stored workout copy
        session.workout = workout

        // Add ExerciseLog entries for any new exercises that weren't present
        for we in workout.exercises {
            let alreadyLogged = session.exerciseLogs.contains { $0.workoutExercise.id == we.id }
            if !alreadyLogged {
                let newLog = ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [])
                session.exerciseLogs.append(newLog)
            }
        }

        let idOrder = workout.exercises.map(\.id)
        session.exerciseLogs.sort { a, b in
            let ai = idOrder.firstIndex(of: a.workoutExercise.id) ?? Int.max
            let bi = idOrder.firstIndex(of: b.workoutExercise.id) ?? Int.max
            return ai < bi
        }

        let validIds = Set(workout.exercises.map(\.id))
        let removedLogs = session.exerciseLogs.filter { !validIds.contains($0.workoutExercise.id) }
        for log in removedLogs {
            if let exId = log.workoutExercise.exerciseId {
                session.activeExerciseIds.removeAll { $0 == exId }
                session.completedExerciseIds.removeAll { $0 == exId }
            }
        }
        session.exerciseLogs.removeAll { !validIds.contains($0.workoutExercise.id) }

        currentSession = session
        saveActiveSession()
    }

    /// Appends a concrete exercise to the in-memory session workout (e.g. flexible template sessions, whose workout id is not in `userWorkouts`).
    func appendExerciseToSession(
        exercise: Exercise,
        recommendedSets: Int,
        recommendedReps: String,
        configurationFields: [String],
        recommendedConfigBySet: [[String: String]]
    ) {
        guard var session = currentSession else { return }
        let we = WorkoutExercise(
            id: UUID(),
            exercise: exercise,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            configurationFields: configurationFields,
            recommendedConfigBySet: recommendedConfigBySet
        )
        session.workout.exercises.append(we)
        session.exerciseLogs.append(ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: []))
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Appends a new flexible slot to the backing library workout and a matching row to the active session.
    func appendSlotToFlexibleLibrarySession() {
        guard var session = currentSession,
              case .workout(let libraryId) = session.sessionPlanOrigin,
              let lib = dataManager.workout(id: libraryId),
              lib.hasFlexibleSlots
        else { return }

        let n = dataManager.flexibleSlots(from: lib).count + 1
        let newSlot = TemplateSlot(
            label: "Slot \(n)",
            targetedMuscles: [.chest],
            exerciseRole: .compound,
            movementPattern: .horizontalPush,
            defaultExerciseId: nil,
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8-12"
        )
        dataManager.appendFlexibleSlot(toWorkoutId: libraryId, slot: newSlot)

        let weId = UUID()
        let we = WorkoutExercise(
            id: weId,
            resolution: .flexible(newSlot.asSlotBlueprint()),
            defaultRestTime: newSlot.defaultRestTime,
            recommendedSets: newSlot.recommendedSets,
            recommendedReps: newSlot.recommendedReps
        )
        session.workout.exercises.append(we)
        session.workout.templateSlotIdByWorkoutExerciseId[weId] = newSlot.id
        session.exerciseLogs.append(ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: []))
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Removes the exercise row at the given log index from the session (and from the saved workout when this session uses a `userWorkouts` definition).
    func removeExerciseFromSession(exerciseLogIndex: Int, undoManager: UndoManager? = nil) {
        guard var session = currentSession,
              exerciseLogIndex >= 0,
              exerciseLogIndex < session.exerciseLogs.count else { return }
        let rowId = session.exerciseLogs[exerciseLogIndex].workoutExercise.id
        let workout = session.workout

        if dataManager.userWorkouts.contains(where: { $0.id == workout.id }) {
            guard let snap = dataManager.deleteExerciseReturningSnapshot(from: workout, exerciseId: rowId) else { return }
            if let updated = dataManager.userWorkouts.first(where: { $0.id == workout.id }) {
                syncExercises(withUpdatedWorkout: updated)
            }
            recordWorkoutActivity()
            if let um = undoManager {
                um.registerUndo(withTarget: um) { [weak self] _ in
                    guard let self else { return }
                    self.dataManager.restoreWorkoutExercise(snap)
                    if let w = self.dataManager.userWorkouts.first(where: { $0.id == snap.workoutId }) {
                        self.syncExercises(withUpdatedWorkout: w)
                    }
                    self.recordWorkoutActivity()
                }
                um.setActionName("Remove Exercise")
            }
            return
        }

        let we = session.exerciseLogs[exerciseLogIndex].workoutExercise
        if case .workout(let libraryId) = session.sessionPlanOrigin,
           let slotId = session.workout.templateSlotIdByWorkoutExerciseId[rowId],
           let lib = dataManager.workout(id: libraryId),
           lib.hasFlexibleSlots {
            dataManager.removeFlexibleSlot(fromWorkoutId: libraryId, slotId: slotId)
        }

        if let exId = we.exerciseId {
            session.activeExerciseIds.removeAll { $0 == exId }
            session.completedExerciseIds.removeAll { $0 == exId }
        }
        session.workout.exercises.removeAll { $0.id == rowId }
        session.workout.templateSlotIdByWorkoutExerciseId.removeValue(forKey: rowId)
        session.exerciseLogs.removeAll { $0.workoutExercise.id == rowId }

        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Reorders exercises for the active session. Library-backed workouts update `userWorkouts` and resync logs; ad-hoc sessions reorder the in-memory workout snapshot and logs together.
    func moveExerciseLogs(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard var session = currentSession else { return }
        let rowCount = session.exerciseLogs.count
        guard rowCount > 0 else { return }

        let safeSource = IndexSet(source.filter { $0 >= 0 && $0 < rowCount })
        guard !safeSource.isEmpty else { return }
        let safeDestination = min(max(0, destination), rowCount)

        let workoutId = session.workout.id
        if dataManager.userWorkouts.contains(where: { $0.id == workoutId }) {
            dataManager.moveExercise(in: session.workout, from: safeSource, to: safeDestination)
            if let updated = dataManager.userWorkouts.first(where: { $0.id == workoutId }) {
                syncExercises(withUpdatedWorkout: updated)
            }
            recordWorkoutActivity()
        } else {
            guard session.workout.exercises.count == rowCount else {
                // Session rows drifted out of sync; avoid index traps and rebuild from workout snapshot.
                syncExercises(withUpdatedWorkout: session.workout)
                return
            }
            session.workout.exercises.move(fromOffsets: safeSource, toOffset: safeDestination)
            session.exerciseLogs.move(fromOffsets: safeSource, toOffset: safeDestination)
            currentSession = session
            recordWorkoutActivity()
            saveActiveSession()
        }
    }

    func setSessionNotes(_ text: String) {
        guard var session = currentSession else { return }
        session.sessionNotes = text
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    func setExerciseLogNotes(at index: Int, notes: String) {
        guard var session = currentSession, session.exerciseLogs.indices.contains(index) else { return }
        session.exerciseLogs[index].notes = notes
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Session-only default rest for the next set when this exercise has no logged sets yet (does not change the library workout).
    func setExerciseLogSessionRestOverride(at index: Int, seconds: Int) {
        guard var session = currentSession, session.exerciseLogs.indices.contains(index) else { return }
        let clamped = min(300, max(0, seconds))
        let planDefault = session.exerciseLogs[index].workoutExercise.defaultRestTime
        session.exerciseLogs[index].sessionRestOverrideSeconds = (clamped == planDefault) ? nil : clamped
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    func clearExerciseLogSessionRestOverride(at index: Int) {
        guard var session = currentSession, session.exerciseLogs.indices.contains(index) else { return }
        session.exerciseLogs[index].sessionRestOverrideSeconds = nil
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Replace a template slot placeholder with a real exercise while preserving `WorkoutExercise.id` (stable for logs).
    /// Swapping an already-resolved exercise clears its logged sets.
    func resolveSlotPlaceholder(workoutExerciseId: UUID, exercise: Exercise) {
        guard var session = currentSession else { return }
        let snap = ExerciseSnapshot(from: exercise)

        if session.workout.templateSlotIdByWorkoutExerciseId[workoutExerciseId] == nil,
           let weForBinding = session.workout.exercises.first(where: { $0.id == workoutExerciseId }),
           let tid = weForBinding.templateSlotId {
            session.workout.templateSlotIdByWorkoutExerciseId[workoutExerciseId] = tid
        }

        if let wi = session.workout.exercises.firstIndex(where: { $0.id == workoutExerciseId }) {
            var we = session.workout.exercises[wi]
            let oldId = we.exerciseId
            let isSwap = oldId != nil && oldId != snap.exerciseId
            if isSwap, let oid = oldId {
                session.activeExerciseIds.removeAll { $0 == oid }
                session.completedExerciseIds.removeAll { $0 == oid }
            }
            we.resolution = .concrete(snap)
            session.workout.exercises[wi] = we
        }
        if let li = session.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == workoutExerciseId }) {
            var we = session.exerciseLogs[li].workoutExercise
            let oldId = we.exerciseId
            let isSwap = oldId != nil && oldId != snap.exerciseId
            if isSwap {
                session.exerciseLogs[li].loggedSets = []
                if let oid = oldId {
                    session.activeExerciseIds.removeAll { $0 == oid }
                    session.completedExerciseIds.removeAll { $0 == oid }
                }
            }
            we.resolution = .concrete(snap)
            session.exerciseLogs[li].workoutExercise = we
        }

        if let origin = session.sessionPlanOrigin,
           case .workout(let libraryId) = origin,
           let lib = dataManager.workout(id: libraryId), lib.hasFlexibleSlots,
           let slotId = session.workout.templateSlotIdByWorkoutExerciseId[workoutExerciseId],
           var slot = dataManager.flexibleSlots(from: lib).first(where: { $0.id == slotId }) {
            slot.defaultExerciseId = exercise.id
            dataManager.updateFlexibleSlot(workoutId: libraryId, slot: slot)
        }

        currentSession = session
        saveActiveSession()
    }

    /// Swap the exercise at the given log index with a new exercise (mid-session swap).
    /// Preserves already-logged sets and slot context.
    func swapExercise(atIndex exerciseIndex: Int, to exercise: Exercise) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        let snap = ExerciseSnapshot(from: exercise)
        let workoutExerciseId = session.exerciseLogs[exerciseIndex].workoutExercise.id

        // Update workout exercises snapshot
        if let wi = session.workout.exercises.firstIndex(where: { $0.id == workoutExerciseId }) {
            let oldId = session.workout.exercises[wi].exerciseId
            var we = session.workout.exercises[wi]
            if let oid = oldId, oid != snap.exerciseId {
                session.activeExerciseIds.removeAll { $0 == oid }
                session.completedExerciseIds.removeAll { $0 == oid }
            }
            we.resolution = .concrete(snap)
            session.workout.exercises[wi] = we
        }
        // Update exercise log's workoutExercise (keep logged sets)
        var we = session.exerciseLogs[exerciseIndex].workoutExercise
        we.resolution = .concrete(snap)
        session.exerciseLogs[exerciseIndex].workoutExercise = we

        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Log another set identical to the last one for this exercise (quick repeat).
    func repeatLastSet(exerciseIndex: Int) {
        guard let session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        guard let last = session.exerciseLogs[exerciseIndex].loggedSets.last else { return }
        logSet(
            exerciseIndex: exerciseIndex,
            weight: last.weight,
            reps: last.reps,
            restTime: last.restTime,
            setType: last.setType,
            configuration: last.configuration,
            dropSegments: last.dropSegments,
            rpe: last.rpe
        )
    }
    
    func logSet(
        exerciseIndex: Int,
        weight: Double,
        reps: Int,
        restTime: Int,
        setType: ExerciseSetType = .working,
        configuration: [String: String] = [:],
        dropSegments: [DropSetSegment] = [],
        rpe: Double? = nil
    ) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        guard let exId = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId else { return }

        let resolvedSetType: ExerciseSetType = {
            if !dropSegments.isEmpty { return .dropSet }
            switch setType {
            case .dropSet:
                return .working
            default:
                return setType
            }
        }()
        let set = LoggedSet(
            id: UUID(),
            weight: weight,
            reps: reps,
            restTime: restTime,
            timestamp: Date(),
            setType: resolvedSetType,
            configuration: configuration,
            dropSegments: dropSegments,
            rpe: rpe
        )
        let exerciseName = dataManager.displayName(for: session.exerciseLogs[exerciseIndex].workoutExercise)
        // O(1) PR detection via pre-computed SDPersonalRecordV2 rows — no full-history scan needed.
        let prEvents = dataManager.prStore.updateIfPR(
            set: set,
            exerciseId: exId,
            exerciseName: exerciseName,
            sessionId: session.id
        )
        session.exerciseLogs[exerciseIndex].loggedSets.append(set)
        let isAlreadyActive = session.activeExerciseIds.contains(exId)

        // If logging a set on a different, not-yet-active exercise, complete the previous primary
        // and switch the primary to this exercise.
        if let current = session.activeExerciseIds.first,
           current != exId,
           !isAlreadyActive {
            if !session.completedExerciseIds.contains(current) {
                session.completedExerciseIds.append(current)
            }
            session.activeExerciseIds.removeAll { $0 == current }
        }

        if isAlreadyActive {
            // Already in superset — keep existing order stable.
        } else {
            // New exercise — make it active and primary (insert at front).
            session.activeExerciseIds.insert(exId, at: 0)
        }

        // Once we log a set again, it is no longer considered explicitly completed.
        session.completedExerciseIds.removeAll { $0 == exId }

        currentSession = session
        recentPersonalRecordEvent = prioritizedPREvent(from: prEvents)
        recordWorkoutActivity()

        // Start live countdown
        startRestCountdown(seconds: restTime)

        if restTime > 0 {
            scheduleRestNotification(seconds: restTime)
        } else {
            clearRestCompletionNotification()
        }
        saveActiveSession()
    }

    /// Updates weight/reps (and optional type) on an existing logged set (inline edit). Does not re-run PR detection or rest timer.
    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, setType: ExerciseSetType? = nil) {
        guard var session = currentSession,
              exerciseIndex < session.exerciseLogs.count,
              setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count
        else { return }
        session.exerciseLogs[exerciseIndex].loggedSets[setIndex].weight = weight
        session.exerciseLogs[exerciseIndex].loggedSets[setIndex].reps = reps
        if !session.exerciseLogs[exerciseIndex].loggedSets[setIndex].dropSegments.isEmpty {
            session.exerciseLogs[exerciseIndex].loggedSets[setIndex].setType = .dropSet
        } else if let setType {
            session.exerciseLogs[exerciseIndex].loggedSets[setIndex].setType =
                setType == .dropSet ? .working : setType
        }
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    private func prioritizedPREvent(from events: [PersonalRecordEvent]) -> PersonalRecordEvent? {
        guard !events.isEmpty else { return nil }
        func rank(_ kind: PersonalRecordEvent.Kind) -> Int {
            switch kind {
            case .maxWeight: return 3
            case .estimatedOneRM: return 2
            case .maxVolumeSet: return 1
            case .maxDistance, .bestPace, .longestDuration, .maxCalories: return 0
            }
        }
        return events.max { rank($0.kind) < rank($1.kind) }
    }
    
    private func startRestCountdown(seconds: Int) {
        restTimer?.invalidate()
        restTimer = nil
        remainingRestTime = max(0, seconds)
        restCountdownTotalSeconds = seconds
        showRestCompleteAlert = false

        guard seconds > 0 else {
            restCountdownTotalSeconds = 0
            return
        }

        let workoutTitle = currentSession?.workout.name ?? "Workout"
        Task { @MainActor in
            RestTimerLiveActivityCoordinator.shared.syncRestCountdown(
                remainingSeconds: remainingRestTime,
                workoutName: workoutTitle
            )
        }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingRestTime -= 1
            let title = self.currentSession?.workout.name ?? "Workout"
            if self.remainingRestTime > 0 {
                Task { @MainActor in
                    RestTimerLiveActivityCoordinator.shared.syncRestCountdown(
                        remainingSeconds: self.remainingRestTime,
                        workoutName: title
                    )
                }
            }
            if self.remainingRestTime <= 0 {
                self.restTimer?.invalidate()
                self.restTimer = nil
                self.restCountdownTotalSeconds = 0
                Task { @MainActor in
                    RestTimerLiveActivityCoordinator.shared.endRestActivity()
                }
                Self.playRestCompleteFeedback()
                self.showRestCompleteAlert = true
            }
        }
    }

    private static func playRestCompleteFeedback() {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
        #endif
        AudioServicesPlaySystemSound(1005)
    }
    
    func cancelRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        remainingRestTime = 0
        restCountdownTotalSeconds = 0
        showRestCompleteAlert = false
        clearRestCompletionNotification()
        Task { @MainActor in
            RestTimerLiveActivityCoordinator.shared.endRestActivity()
        }
    }

    /// Nudge the active rest countdown (e.g. +15 / −15) without restarting the timer tick loop.
    func adjustRestCountdown(by delta: Int) {
        guard delta != 0 else { return }
        guard remainingRestTime > 0 || restTimer != nil else { return }
        let capped = min(600, max(0, remainingRestTime + delta))
        if capped == 0 {
            cancelRestTimer()
            return
        }
        remainingRestTime = capped
        restCountdownTotalSeconds = max(restCountdownTotalSeconds, capped)
        clearRestCompletionNotification()
        scheduleRestNotification(seconds: capped)
        let title = currentSession?.workout.name ?? "Workout"
        Task { @MainActor in
            RestTimerLiveActivityCoordinator.shared.syncRestCountdown(
                remainingSeconds: capped,
                workoutName: title
            )
        }
    }

    private func clearRestCompletionNotification() {
        let id = Self.restCompleteNotificationIdentifier
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        let id = Self.restCompleteNotificationIdentifier
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Rest Over! 💪"
        content.body = "Time for the next set"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        center.add(request)
    }
    
    func addEmptySet(toExerciseIndex: Int) {
        guard var session = currentSession, toExerciseIndex < session.exerciseLogs.count else { return }
        
        let emptySet = LoggedSet(id: UUID(), weight: 0.0, reps: 0, restTime: 90, timestamp: Date(), isWarmup: false, configuration: [:], dropSegments: [], rpe: nil)
        session.exerciseLogs[toExerciseIndex].loggedSets.append(emptySet)
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    func deleteSet(exerciseIndex: Int, setIndex: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count, setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count else { return }
        
        session.exerciseLogs[exerciseIndex].loggedSets.remove(at: setIndex)
        guard let exId = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId else { return }
        // If no sets remain, this exercise is no longer active or completed.
        if session.exerciseLogs[exerciseIndex].loggedSets.isEmpty {
            session.activeExerciseIds.removeAll { $0 == exId }
            session.completedExerciseIds.removeAll { $0 == exId }
        }
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }

    /// Restores a set after swipe-delete undo (inserts at clamped index).
    func insertLoggedSet(_ set: LoggedSet, exerciseIndex: Int, at setIndex: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        var sets = session.exerciseLogs[exerciseIndex].loggedSets
        let i = min(max(0, setIndex), sets.count)
        sets.insert(set, at: i)
        session.exerciseLogs[exerciseIndex].loggedSets = sets
        if let exId = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId,
           !session.activeExerciseIds.contains(exId) {
            session.activeExerciseIds.insert(exId, at: 0)
        }
        currentSession = session
        recordWorkoutActivity()
        saveActiveSession()
    }
    
    func appDidEnterBackground() {
        if remainingRestTime > 0 {
            wasTimerRunning = true
            backgroundDate = Date()
            restTimer?.invalidate()
        }
        if currentSession != nil && currentSession?.endTime == nil {
            saveActiveSession()
            saveTimerState()
        }
    }

    func appDidBecomeActive() {
        if wasTimerRunning, let bgDate = backgroundDate {
            let elapsed = Date().timeIntervalSince(bgDate)
            remainingRestTime = max(0, remainingRestTime - Int(elapsed))
            if remainingRestTime > 0 {
                startRestCountdown(seconds: remainingRestTime)
            } else {
                Task { @MainActor in
                    RestTimerLiveActivityCoordinator.shared.endRestActivity()
                }
            }
            backgroundDate = nil
            wasTimerRunning = false
        }
        if currentSession != nil && workoutPausedAt == nil {
            updateWorkoutElapsed()
        }
    }

    // MARK: - Inactivity reminder

    /// Call whenever the user performs an action within an active workout (e.g. log set, pause/resume).
    private func recordWorkoutActivity() {
        guard isInProgress else {
            clearInactivityReminder()
            return
        }
        lastActivityDate = Date()
        scheduleInactivityReminder()
    }

    /// Schedules (or reschedules) a local notification to remind the user that a workout is still active
    /// if there is no further activity for 10 minutes.
    private func scheduleInactivityReminder() {
        guard isInProgress else {
            clearInactivityReminder()
            return
        }

        // Cancel any existing reminder.
        if let id = inactivityNotificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }

        let newId = UUID().uuidString
        inactivityNotificationIdentifier = newId

        let content = UNMutableNotificationContent()
        content.title = "Workout still in progress"
        content.body = "You have an active workout in The Workout Log. End it if you're finished."
        content.sound = .default

        // Fire in 10 minutes unless more activity occurs (which will reschedule).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: newId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func clearInactivityReminder() {
        if let id = inactivityNotificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
        inactivityNotificationIdentifier = nil
    }

    // MARK: - Exercise status helpers (current / superset)

    /// Mark the given exercise as the primary current exercise and ensure it's active.
    func setPrimaryExercise(exerciseId: UUID) {
        guard var session = currentSession else { return }
        // Ensure in active list
        if !session.activeExerciseIds.contains(exerciseId) {
            session.activeExerciseIds.append(exerciseId)
        }
        // Move to front to make it primary
        session.activeExerciseIds.removeAll { $0 == exerciseId }
        session.activeExerciseIds.insert(exerciseId, at: 0)
        currentSession = session
        recordWorkoutActivity()
    }

    /// Toggle this exercise in the superset list (activeExerciseIds) without changing primary.
    func toggleSupersetExercise(exerciseId: UUID) {
        guard var session = currentSession else { return }
        if let idx = session.activeExerciseIds.firstIndex(of: exerciseId) {
            session.activeExerciseIds.remove(at: idx)
        } else {
            session.activeExerciseIds.append(exerciseId)
        }
        currentSession = session
        recordWorkoutActivity()
    }

    /// Explicitly mark an exercise as completed; it will be shown as completed in the UI.
    func markExerciseCompleted(exerciseId: UUID) {
        guard var session = currentSession else { return }
        if !session.completedExerciseIds.contains(exerciseId) {
            session.completedExerciseIds.append(exerciseId)
        }
        // Once completed, it's no longer active unless user reactivates via logging or toggle.
        session.activeExerciseIds.removeAll { $0 == exerciseId }
        currentSession = session
        recordWorkoutActivity()
    }

    /// Undo an explicit early completion so the exercise shows as in-progress again.
    func markExerciseNotCompleted(exerciseId: UUID) {
        guard var session = currentSession else { return }
        session.completedExerciseIds.removeAll { $0 == exerciseId }
        currentSession = session
        recordWorkoutActivity()
    }

    // MARK: - Starting a workout while another may be active

    /// Whether the in-progress session is the same logical plan as the workout being started.
    func isActiveSessionMatching(workout: Workout, planRef: WorkoutPlanRef?) -> Bool {
        guard let s = currentSession, s.endTime == nil else { return false }
        if let pr = planRef, let origin = s.sessionPlanOrigin {
            return origin == pr
        }
        return s.workout.id == workout.id
    }

    func resolveStartingWorkout(_ workout: Workout, sessionPlanOrigin: WorkoutPlanRef?) -> WorkoutStartResolution {
        guard isInProgress else {
            return .performStart
        }
        if isActiveSessionMatching(workout: workout, planRef: sessionPlanOrigin) {
            return .noOpAlreadyActive
        }
        return .needsReplaceConfirmation(PendingWorkoutReplace(workout: workout, sessionPlanOrigin: sessionPlanOrigin))
    }

    /// Like `resolveStartingWorkout`, but when a replace is required the payload includes `resumedSession` for apply-after-stop.
    func resolveStartingResumedSession(_ resumed: WorkoutSession) -> WorkoutStartResolution {
        switch resolveStartingWorkout(resumed.workout, sessionPlanOrigin: resumed.sessionPlanOrigin) {
        case .performStart:
            return .performStart
        case .noOpAlreadyActive:
            return .noOpAlreadyActive
        case .needsReplaceConfirmation:
            return .needsReplaceConfirmation(
                PendingWorkoutReplace(
                    workout: resumed.workout,
                    sessionPlanOrigin: resumed.sessionPlanOrigin,
                    resumedSession: resumed
                )
            )
        }
    }

    /// Ends the current session (saved as completed) and starts the new one.
    func stopThenStartWorkout(_ workout: Workout, sessionPlanOrigin: WorkoutPlanRef? = nil) {
        stopWorkout()
        startWorkout(workout, sessionPlanOrigin: sessionPlanOrigin)
    }

    /// Ends the current session (saved) and continues with a resumed in-progress snapshot (same sets/state as when that session was finished).
    func stopThenApplyResumedSession(_ resumed: WorkoutSession) {
        stopWorkout()
        beginInProgressSession(resumed)
    }

    /// Starts immediately, or invokes `onNeedReplaceConfirmation` when the user must confirm replacing the active session.
    func startWorkoutResolvingConflict(
        _ workout: Workout,
        sessionPlanOrigin: WorkoutPlanRef?,
        onNeedReplaceConfirmation: (PendingWorkoutReplace) -> Void
    ) {
        switch resolveStartingWorkout(workout, sessionPlanOrigin: sessionPlanOrigin) {
        case .performStart:
            startWorkout(workout, sessionPlanOrigin: sessionPlanOrigin)
        case .noOpAlreadyActive:
            break
        case .needsReplaceConfirmation(let pending):
            onNeedReplaceConfirmation(pending)
        }
    }

    /// Resumes from a **completed** session (copied logs and UI state). Same replace-active flow as `startWorkoutResolvingConflict`.
    func startWorkoutResumingFromCompleted(
        _ completed: WorkoutSession,
        onNeedReplaceConfirmation: @escaping (PendingWorkoutReplace) -> Void
    ) {
        let resumed = WorkoutSession.resumingFromCompletedSession(completed)
        switch resolveStartingResumedSession(resumed) {
        case .performStart:
            beginInProgressSession(resumed)
        case .noOpAlreadyActive:
            break
        case .needsReplaceConfirmation(let pending):
            onNeedReplaceConfirmation(pending)
        }
    }
}

// MARK: - Replace-active confirmation payload

enum WorkoutStartResolution {
    case performStart
    case noOpAlreadyActive
    case needsReplaceConfirmation(PendingWorkoutReplace)
}

struct PendingWorkoutReplace: Identifiable {
    let id = UUID()
    let workout: Workout
    let sessionPlanOrigin: WorkoutPlanRef?
    /// When set, confirming replace applies this in-progress session instead of starting an empty workout from `workout`.
    var resumedSession: WorkoutSession? = nil
}
