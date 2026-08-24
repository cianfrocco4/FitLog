//
//  ActiveExerciseRound.swift
//  FitLog
//
//  Pure transitions for `WorkoutSession.activeExerciseIds`.
//

import Foundation

/// `WorkoutSession.activeExerciseIds` carries two meanings: the first element is the current
/// exercise, and more than one element means the user is running a superset round (letters
/// A, B, C in the UI). Only `togglingSupersetMember` may grow the list, so navigating between
/// exercises or adding a row mid-workout can never produce an unexplained superset.
enum ActiveExerciseRound {

    /// Focuses `exerciseId` without joining it to a superset.
    ///
    /// An explicit round is preserved when the target already belongs to it — the letters just
    /// reorder so the focused exercise is current. Otherwise the round ends and only the target
    /// stays active. Unlike logging a set, this never marks the previous exercise completed.
    static func makingPrimary(_ exerciseId: UUID, in current: [UUID]) -> [UUID] {
        guard current.contains(exerciseId), current.count > 1 else { return [exerciseId] }
        var updated = current
        updated.removeAll { $0 == exerciseId }
        updated.insert(exerciseId, at: 0)
        return updated
    }

    /// Adding an exercise to the workout only sets focus when nothing is active yet.
    static func afterAddingExerciseToWorkout(_ exerciseId: UUID, in current: [UUID]) -> [UUID] {
        current.isEmpty ? [exerciseId] : current
    }

    /// The one path that may grow the round, driven by an explicit "Add to superset round" action.
    static func togglingSupersetMember(_ exerciseId: UUID, in current: [UUID]) -> [UUID] {
        var updated = current
        if let idx = updated.firstIndex(of: exerciseId) {
            updated.remove(at: idx)
        } else {
            updated.append(exerciseId)
        }
        return updated
    }

    /// Collapses a round back to the current exercise.
    static func endingSupersetRound(in current: [UUID]) -> [UUID] {
        guard let primary = current.first else { return [] }
        return [primary]
    }

    /// True when the letters and round switcher should be shown.
    static func isSupersetRound(_ current: [UUID]) -> Bool {
        current.count > 1
    }
}
