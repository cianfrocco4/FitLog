//
//  CurrentWorkoutSessionViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import UserNotifications

private enum PersistenceKey {
    static let activeSession = "activeWorkoutSession"
    static let timerTotalPaused = "activeWorkoutTimerTotalPaused"
    static let timerIsPaused = "activeWorkoutTimerIsPaused"
    static let timerPausedAt = "activeWorkoutTimerPausedAt"
}

final class CurrentWorkoutSessionViewModel: ObservableObject {
    /// Set from the app root so completed workouts persist through `DataManager` (backups + in-memory list stay in sync).
    weak var dataManager: DataManager?

    @Published var currentSession: WorkoutSession?
    @Published var remainingRestTime: Int = 0
    /// Elapsed workout time in seconds (excluding paused time). Updates every second when running.
    @Published var workoutElapsedSeconds: Int = 0
    /// Set to true when a rest countdown naturally reaches zero (not when cancelled).
    @Published var showRestCompleteAlert: Bool = false
    
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
    
    init() {
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
        if let firstId = workout.exercises.first?.exercise.id {
            session.activeExerciseIds = [firstId]
        }
        session.completedExerciseIds = []
        currentSession = session
        totalPausedDuration = 0
        workoutPausedAt = nil
        recordWorkoutActivity()
        saveActiveSession()
        saveTimerState()
        startWorkoutTimer()
        updateWorkoutElapsed()
    }
    
    func stopWorkout() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()

        if let dm = dataManager {
            dm.appendCompletedSession(session)
        } else {
            var allSessions: [WorkoutSession] = []
            if let existing = UserDefaults.standard.data(forKey: "completedSessions"),
               let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: existing) {
                allSessions = decoded
            }
            allSessions.append(session)
            if let encoded = try? JSONEncoder().encode(allSessions) {
                UserDefaults.standard.set(encoded, forKey: "completedSessions")
            }
        }

        workoutTimer?.invalidate()
        workoutTimer = nil
        cancelRestTimer()
        currentSession = nil
        workoutElapsedSeconds = 0
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
        workoutElapsedSeconds = computedElapsedSeconds()
    }
    
    private func startWorkoutTimer() {
        guard currentSession != nil, workoutPausedAt == nil else { return }
        workoutTimer?.invalidate()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateWorkoutElapsed()
        }
        RunLoop.main.add(workoutTimer!, forMode: .common)
    }
    
    // MARK: - Persistence (background / restart)
    
    private func saveActiveSession() {
        guard let session = currentSession, session.endTime == nil,
              let data = try? JSONEncoder().encode(session) else {
            return
        }
        UserDefaults.standard.set(data, forKey: PersistenceKey.activeSession)
    }
    
    private func saveTimerState() {
        UserDefaults.standard.set(totalPausedDuration, forKey: PersistenceKey.timerTotalPaused)
        UserDefaults.standard.set(workoutPausedAt != nil, forKey: PersistenceKey.timerIsPaused)
        UserDefaults.standard.set(workoutPausedAt?.timeIntervalSince1970, forKey: PersistenceKey.timerPausedAt)
    }
    
    private func clearPersistedActiveSession() {
        UserDefaults.standard.removeObject(forKey: PersistenceKey.activeSession)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerTotalPaused)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerIsPaused)
        UserDefaults.standard.removeObject(forKey: PersistenceKey.timerPausedAt)
    }
    
    private func restoreActiveSessionIfNeeded() {
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
        updateWorkoutElapsed()
        if workoutPausedAt == nil {
            startWorkoutTimer()
        }
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

        currentSession = session
    }

    /// Replace a template slot placeholder with a real exercise while preserving `WorkoutExercise.id` (stable for logs).
    func resolveSlotPlaceholder(workoutExerciseId: UUID, exercise: Exercise) {
        guard var session = currentSession else { return }
        if let wi = session.workout.exercises.firstIndex(where: { $0.id == workoutExerciseId }) {
            session.workout.exercises[wi].exercise = exercise
            session.workout.exercises[wi].isSlotPlaceholder = false
        }
        if let li = session.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == workoutExerciseId }) {
            session.exerciseLogs[li].workoutExercise.exercise = exercise
            session.exerciseLogs[li].workoutExercise.isSlotPlaceholder = false
        }
        currentSession = session
        saveActiveSession()
    }
    
    func logSet(exerciseIndex: Int, weight: Double, reps: Int, restTime: Int, isWarmup: Bool = false, configuration: [String: String] = [:], dropSegments: [DropSetSegment] = []) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        guard !session.exerciseLogs[exerciseIndex].workoutExercise.isSlotPlaceholder else { return }

        let set = LoggedSet(id: UUID(), weight: weight, reps: reps, restTime: restTime, timestamp: Date(), isWarmup: isWarmup, configuration: configuration, dropSegments: dropSegments)
        session.exerciseLogs[exerciseIndex].loggedSets.append(set)

        let exId = session.exerciseLogs[exerciseIndex].workoutExercise.exercise.id
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

        // Ensure this exercise is active and primary.
        session.activeExerciseIds.removeAll { $0 == exId }
        session.activeExerciseIds.insert(exId, at: 0)

        // Once we log a set again, it is no longer considered explicitly completed.
        session.completedExerciseIds.removeAll { $0 == exId }

        currentSession = session
        recordWorkoutActivity()

        // Start live countdown
        startRestCountdown(seconds: restTime)

        if restTime > 0 {
            scheduleRestNotification(seconds: restTime)
        } else {
            clearRestCompletionNotification()
        }
    }
    
    private func startRestCountdown(seconds: Int) {
        restTimer?.invalidate()
        restTimer = nil
        remainingRestTime = max(0, seconds)
        showRestCompleteAlert = false

        guard seconds > 0 else { return }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingRestTime -= 1
            if self.remainingRestTime <= 0 {
                self.restTimer?.invalidate()
                self.restTimer = nil
                self.showRestCompleteAlert = true
            }
        }
    }
    
    func cancelRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        remainingRestTime = 0
        showRestCompleteAlert = false
        clearRestCompletionNotification()
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
        
        let emptySet = LoggedSet(id: UUID(), weight: 0.0, reps: 0, restTime: 90, timestamp: Date(), isWarmup: false, configuration: [:], dropSegments: [])
        session.exerciseLogs[toExerciseIndex].loggedSets.append(emptySet)
        currentSession = session
        recordWorkoutActivity()
    }

    func deleteSet(exerciseIndex: Int, setIndex: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count, setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count else { return }
        
        session.exerciseLogs[exerciseIndex].loggedSets.remove(at: setIndex)
        let exId = session.exerciseLogs[exerciseIndex].workoutExercise.exercise.id
        // If no sets remain, this exercise is no longer active or completed.
        if session.exerciseLogs[exerciseIndex].loggedSets.isEmpty {
            session.activeExerciseIds.removeAll { $0 == exId }
            session.completedExerciseIds.removeAll { $0 == exId }
        }
        currentSession = session
        recordWorkoutActivity()
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
}
