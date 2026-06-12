//
//  CoachStarterPromptGenerator.swift
//  FitLog
//
//  Builds contextual starter prompts from the user's training data.
//

import Foundation

@MainActor
enum CoachStarterPromptGenerator {
    static func prompts(dataVM: DataManager, maxCount: Int = 4) -> [String] {
        var results: [String] = []
        let cal = Calendar.current
        let today = Date()

        // Today's plan
        let engine = TrainingScheduleEngine(calendar: cal)
        let resolved = engine.resolve(date: today, program: dataVM.trainingProgram)
        switch resolved {
        case .workout(let ref):
            let label = dataVM.planLabel(for: ref)
            results.append("Review today's \(label) workout for balance and progression")
        case .rest:
            results.append("What should I focus on during today's rest day?")
        case .unscheduled:
            results.append("Help me decide what to train today based on my recent log")
        }

        // Weekly consistency
        let sessionsThisWeek = dataVM.workoutsThisWeek
        let goal = dataVM.trainingProgram.sessionsPerWeek
        if goal > 0 {
            if sessionsThisWeek < goal {
                results.append("I'm at \(sessionsThisWeek) of \(goal) sessions this week — what should I prioritize?")
            } else if sessionsThisWeek >= goal {
                results.append("Review my training consistency this week")
            }
        }

        // Busiest workout template
        if let busiest = busiestWorkout(in: dataVM.userWorkouts) {
            results.append("Review my \(busiest.name) day for exercise balance")
        }

        // Recent gap
        if let last = dataVM.completedSessions
            .filter(\.isCompleted)
            .sorted(by: { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) })
            .first,
           let end = last.endTime ?? Optional(last.startTime) {
            let days = cal.dateComponents([.day], from: end, to: today).day ?? 0
            if days >= 4 {
                results.append("I haven't trained in \(days) days — suggest a gentle way back in")
            }
        }

        // Program structure
        if !dataVM.trainingProgram.cycleEntries.isEmpty {
            results.append("How can I improve my current workout split?")
        } else {
            results.append("Help me design a training split that fits my schedule")
        }

        // Dedupe while preserving order
        var seen = Set<String>()
        let unique = results.filter { seen.insert($0).inserted }
        if unique.count >= maxCount { return Array(unique.prefix(maxCount)) }

        let fallbacks = [
            "Suggest a small change for recovery",
            "What should I focus on this week based on my log?",
            "Any exercises I should swap based on my equipment?",
        ]
        var merged = unique
        for f in fallbacks where merged.count < maxCount {
            if seen.insert(f).inserted { merged.append(f) }
        }
        return Array(merged.prefix(maxCount))
    }

    private static func busiestWorkout(in workouts: [Workout]) -> Workout? {
        workouts.max(by: { $0.exercises.count < $1.exercises.count })
    }
}
