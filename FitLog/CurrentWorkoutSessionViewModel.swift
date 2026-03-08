//
//  CurrentWorkoutSessionViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import UserNotifications

final class CurrentWorkoutSessionViewModel: ObservableObject {
    @Published var currentSession: WorkoutSession?
    @Published var remainingRestTime: Int = 0
    
    private var restTimer: Timer?
    private var backgroundDate: Date?
    private var wasTimerRunning = false
    
    var isInProgress: Bool { currentSession != nil && currentSession?.endTime == nil }
    
    func startWorkout(_ workout: Workout) {
        let logs = workout.exercises.map { ex in
            ExerciseLog(id: UUID(), workoutExercise: ex, loggedSets: [])
        }
        currentSession = WorkoutSession(id: UUID(), workout: workout, startTime: Date(), endTime: nil, exerciseLogs: logs)
    }
    
    func stopWorkout() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        
        // Load existing completed sessions (if any), append this one, and save back.
        var allSessions: [WorkoutSession] = []
        
        if let existing = UserDefaults.standard.data(forKey: "completedSessions"),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: existing) {
            allSessions = decoded
        }
        
        allSessions.append(session)
        
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: "completedSessions")
        }
        
        currentSession = nil
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
    
    func logSet(exerciseIndex: Int, weight: Double, reps: Int, restTime: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        
        let set = LoggedSet(id: UUID(), weight: weight, reps: reps, restTime: restTime, timestamp: Date())
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
        
        let emptySet = LoggedSet(id: UUID(), weight: 0.0, reps: 0, restTime: 90, timestamp: Date())
        session.exerciseLogs[toExerciseIndex].loggedSets.append(emptySet)
        currentSession = session
    }

    func deleteSet(exerciseIndex: Int, setIndex: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count, setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count else { return }
        
        session.exerciseLogs[exerciseIndex].loggedSets.remove(at: setIndex)
        currentSession = session
    }
    
    // Call this when app enters background (see next step)
    func appDidEnterBackground() {
        if remainingRestTime > 0 {
            wasTimerRunning = true
            backgroundDate = Date()
            restTimer?.invalidate()  // pause timer while backgrounded
        }
    }

    // Call this when app becomes active
    func appDidBecomeActive() {
        if wasTimerRunning, let bgDate = backgroundDate {
            let elapsed = Date().timeIntervalSince(bgDate)
            remainingRestTime = max(0, remainingRestTime - Int(elapsed))
            
            // Restart live timer with remaining time
            if remainingRestTime > 0 {
                startRestCountdown(seconds: remainingRestTime)
            }
            
            backgroundDate = nil
            wasTimerRunning = false
        }
    }
}
