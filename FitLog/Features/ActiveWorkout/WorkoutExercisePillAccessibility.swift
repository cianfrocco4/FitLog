//
//  WorkoutExercisePillAccessibility.swift
//  FitLog
//
//  VoiceOver copy for in-session exercise pills (including last working load).
//

import Foundation

enum WorkoutExercisePillAccessibility {
    static func pillLabel(
        name: String,
        done: Int,
        rec: Int,
        isPlaceholder: Bool,
        letter: String?,
        repGoal: String?,
        lastLoad: String?
    ) -> String {
        var parts: [String] = []
        if let letter { parts.append("Superset \(letter) of the round") }
        parts.append(name)
        if isPlaceholder { parts.append("needs an exercise") }
        else if rec > 0 { parts.append("\(done) of \(rec) work sets") }
        else if done > 0 { parts.append("\(done) work sets logged") }
        if !isPlaceholder, let repGoal, !repGoal.isEmpty { parts.append("goal \(repGoal) reps") }
        if let lastLoad, !lastLoad.isEmpty { parts.append(lastLoad) }
        return parts.joined(separator: ", ")
    }

    static func nextExerciseBannerLabel(exerciseName: String, lastLoad: String?) -> String {
        var parts = ["Next: \(exerciseName)"]
        if let lastLoad, !lastLoad.isEmpty { parts.append(lastLoad) }
        parts.append("Tap to log")
        return parts.joined(separator: ". ")
    }

    static func supersetChipLabel(letter: String, name: String, lastLoad: String?) -> String {
        var parts = ["Superset \(letter), \(name)"]
        if let lastLoad, !lastLoad.isEmpty { parts.append(lastLoad) }
        return parts.joined(separator: ", ")
    }
}
