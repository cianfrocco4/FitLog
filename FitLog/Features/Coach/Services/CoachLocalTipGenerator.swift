//
//  CoachLocalTipGenerator.swift
//  FitLog
//
//  On-device Coach tab tip so free users see training advice before a Premium CTA
//  (`dislike.coach.premium_gate`).
//

import Foundation

struct CoachLocalTip: Equatable, Sendable {
    var title: String
    var body: String
}

enum CoachLocalTipGenerator {
    struct Context: Equatable, Sendable {
        enum TodayPlan: Equatable, Sendable {
            case rest
            case unscheduled
            case workout(String)
        }

        var lastWorkoutName: String?
        var lastWorkoutIsCardio: Bool
        var lastWorkoutDurationMinutes: Int?
        var daysSinceLastWorkout: Int?
        var sessionsThisWeek: Int
        var weeklyGoal: Int
        var todayPlan: TodayPlan
        var libraryCount: Int
    }

    static func tip(from context: Context) -> CoachLocalTip {
        if let days = context.daysSinceLastWorkout, days == 0, let name = context.lastWorkoutName, !name.isEmpty {
            if context.lastWorkoutIsCardio, let minutes = context.lastWorkoutDurationMinutes, minutes > 0 {
                return CoachLocalTip(
                    title: "Already trained today",
                    body: "\(name) was \(minutes) min. Extra volume is optional — recover well."
                )
            }
            return CoachLocalTip(
                title: "Already trained today",
                body: "\(name) is in the log. Extra volume is optional — recover well."
            )
        }

        if context.lastWorkoutIsCardio,
           let minutes = context.lastWorkoutDurationMinutes,
           minutes > 0,
           let name = context.lastWorkoutName,
           !name.isEmpty {
            let when = gapPhrase(daysSince: context.daysSinceLastWorkout)
            return CoachLocalTip(
                title: "Last cardio",
                body: "\(name) was \(minutes) min \(when). Match that time, or add 5 minutes if it felt easy."
            )
        }

        if let days = context.daysSinceLastWorkout, days >= 4 {
            let session = context.lastWorkoutName.flatMap { $0.isEmpty ? nil : $0 } ?? "your last session"
            return CoachLocalTip(
                title: "Ease back in",
                body: "It's been \(days) days since \(session). Start lighter than last time."
            )
        }

        if context.weeklyGoal > 0, context.sessionsThisWeek < context.weeklyGoal {
            return CoachLocalTip(
                title: "This week's sessions",
                body: "You're at \(context.sessionsThisWeek) of \(context.weeklyGoal) this week. A short session still counts."
            )
        }

        switch context.todayPlan {
        case .rest:
            return CoachLocalTip(
                title: "Rest day",
                body: "Keep this quiet — walk, mobility, and sleep beat inventing extra work."
            )
        case .workout(let name) where !name.isEmpty:
            return CoachLocalTip(
                title: "Today's plan",
                body: "\(name) is on the calendar. Log it when you're ready — you don't need AI to start."
            )
        case .unscheduled, .workout:
            break
        }

        if context.libraryCount == 1 {
            return CoachLocalTip(
                title: "Build a second day",
                body: "You have one saved workout. Add Pull or Legs so you aren't repeating the same day every session."
            )
        }

        return CoachLocalTip(
            title: "Next session",
            body: "Pick a workout you have time for and log the sets. Consistency beats a perfect split."
        )
    }

    /// Snapshot from the live store for the Coach tab.
    @MainActor
    static func makeContext(
        dataVM: DataManager,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Context {
        let last = dataVM.completedSessions
            .filter(\.isCompleted)
            .max { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }

        var lastName: String?
        var lastIsCardio = false
        var lastMinutes: Int?
        var daysSince: Int?
        if let last {
            lastName = last.workout.name
            lastIsCardio = last.workout.workoutKind == .cardio
            let end = last.endTime ?? last.startTime
            daysSince = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: end),
                to: calendar.startOfDay(for: now)
            ).day
            if lastIsCardio {
                let cardio = CardioSessionAggregatesCalculator.aggregates(
                    for: last,
                    exercises: dataVM.globalExercises
                )
                if cardio.durationSeconds > 0 {
                    lastMinutes = max(1, cardio.durationSeconds / 60)
                } else {
                    let wall = Int(end.timeIntervalSince(last.startTime) / 60)
                    if wall > 0 { lastMinutes = wall }
                }
            }
        }

        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let sessionsThisWeek = dataVM.completedSessions.filter { session in
            (session.endTime ?? session.startTime) > weekAgo
        }.count

        let engine = TrainingScheduleEngine(calendar: calendar)
        let resolved = engine.resolve(date: now, program: dataVM.trainingProgram)
        let todayPlan: Context.TodayPlan
        switch resolved {
        case .rest:
            todayPlan = .rest
        case .unscheduled:
            todayPlan = .unscheduled
        case .workout(let ref):
            todayPlan = .workout(dataVM.planLabel(for: ref))
        }

        return Context(
            lastWorkoutName: lastName,
            lastWorkoutIsCardio: lastIsCardio,
            lastWorkoutDurationMinutes: lastMinutes,
            daysSinceLastWorkout: daysSince,
            sessionsThisWeek: sessionsThisWeek,
            weeklyGoal: dataVM.trainingProgram.sessionsPerWeek,
            todayPlan: todayPlan,
            libraryCount: dataVM.userWorkouts.count
        )
    }

    private static func gapPhrase(daysSince: Int?) -> String {
        guard let daysSince else { return "recently" }
        if daysSince <= 0 { return "today" }
        if daysSince == 1 { return "yesterday" }
        return "\(daysSince) days ago"
    }
}
