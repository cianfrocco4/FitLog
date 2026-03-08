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
    @Published var currentSession: WorkoutSession?
    @Published var remainingRestTime: Int = 0
    /// Elapsed workout time in seconds (excluding paused time). Updates every second when running.
    @Published var workoutElapsedSeconds: Int = 0
    
    private var restTimer: Timer?
    private var workoutTimer: Timer?
    private var backgroundDate: Date?
    private var wasTimerRunning = false
    
    /// Total time the workout has been paused (accumulated).
    private var totalPausedDuration: TimeInterval = 0
    /// When the user tapped Pause (nil when running).
    private var workoutPausedAt: Date?
    
    var isInProgress: Bool { currentSession != nil && currentSession?.endTime == nil }
    var isWorkoutPaused: Bool { workoutPausedAt != nil }
    
    init() {
        restoreActiveSessionIfNeeded()
    }
    
    func startWorkout(_ workout: Workout) {
        let logs = workout.exercises.map { ex in
            ExerciseLog(id: UUID(), workoutExercise: ex, loggedSets: [])
        }
        currentSession = WorkoutSession(id: UUID(), workout: workout, startTime: Date(), endTime: nil, exerciseLogs: logs)
        totalPausedDuration = 0
        workoutPausedAt = nil
        saveActiveSession()
        saveTimerState()
        startWorkoutTimer()
        updateWorkoutElapsed()
    }
    
    func stopWorkout() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        
        var allSessions: [WorkoutSession] = []
        if let existing = UserDefaults.standard.data(forKey: "completedSessions"),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: existing) {
            allSessions = decoded
        }
        allSessions.append(session)
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: "completedSessions")
        }
        
        workoutTimer?.invalidate()
        workoutTimer = nil
        currentSession = nil
        workoutElapsedSeconds = 0
        clearPersistedActiveSession()
    }
    
    func pauseWorkout() {
        guard currentSession != nil, workoutPausedAt == nil else { return }
        workoutPausedAt = Date()
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
    
    func logSet(exerciseIndex: Int, weight: Double, reps: Int, restTime: Int, isWarmup: Bool = false) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        
        let set = LoggedSet(id: UUID(), weight: weight, reps: reps, restTime: restTime, timestamp: Date(), isWarmup: isWarmup)
        session.exerciseLogs[exerciseIndex].loggedSets.append(set)
        currentSession = session
        
        // Start live countdown
        startRestCountdown(seconds: restTime)
        
        if restTime > 0 {
            scheduleRestNotification(seconds: restTime)
        }
    }
    
    private func startRestCountdown(seconds: Int) {
        restTimer?.invalidate()
        remainingRestTime = seconds
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingRestTime -= 1
            if self.remainingRestTime <= 0 {
                self.restTimer?.invalidate()
                self.restTimer = nil
                // Optional: play sound or haptic here
            }
        }
    }
    
    func cancelRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        remainingRestTime = 0
    }
    
    private func scheduleRestNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Over! 💪"
        content.body = "Time for the next set"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func addEmptySet(toExerciseIndex: Int) {
        guard var session = currentSession, toExerciseIndex < session.exerciseLogs.count else { return }
        
        let emptySet = LoggedSet(id: UUID(), weight: 0.0, reps: 0, restTime: 90, timestamp: Date(), isWarmup: false)
        session.exerciseLogs[toExerciseIndex].loggedSets.append(emptySet)
        currentSession = session
    }

    func deleteSet(exerciseIndex: Int, setIndex: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count, setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count else { return }
        
        session.exerciseLogs[exerciseIndex].loggedSets.remove(at: setIndex)
        currentSession = session
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
}
