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
        guard var session = currentSession else  { return }
        
        session.endTime = Date()
        
        // Save to completed
        if let data = try? JSONEncoder().encode([session]), let existing = UserDefaults.standard.data(forKey: "completedSessions"),
           var all = try? JSONDecoder().decode([WorkoutSession].self, from: existing) {
            all.append(session)
            if let encoded = try? JSONEncoder().encode(all) {
                UserDefaults.standard.set(encoded, forKey: "completedSessions")
            }
        }
        currentSession = nil
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
