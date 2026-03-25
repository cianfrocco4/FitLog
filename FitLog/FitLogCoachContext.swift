//
//  FitLogCoachContext.swift
//  FitLog
//
//  Bounded text snapshot of user data for the in-app AI coach (no API keys or PII beyond workout content).
//

import Foundation

extension DataManager {
    /// Compact snapshot for the coach model; capped to limit tokens and cost.
    func coachDataContextSnapshot(maxCharacters: Int = 14_000) -> String {
        let cal = Calendar.current
        let engine = TrainingScheduleEngine(calendar: cal)
        let today = Date()
        let todayResolved = engine.resolve(date: today, program: trainingProgram)
        let todayLabel: String = {
            switch todayResolved {
            case .rest:
                return "Rest day"
            case .unscheduled:
                return "No workout scheduled (off)"
            case .workout(let ref):
                return "Workout: \(planLabel(for: ref))"
            }
        }()

        var lines: [String] = []
        lines.append("# FitLog snapshot")
        lines.append("Generated (device local date): \(today.formatted(date: .abbreviated, time: .omitted))")
        lines.append("")
        lines.append("## Today’s plan (from calendar)")
        lines.append(todayLabel)
        lines.append("")

        lines.append("## Training program")
        if trainingProgram.cycleEntries.isEmpty {
            lines.append("- Split cycle: (not configured)")
        } else {
            let names = trainingProgram.cycleEntries.map { cycleEntryDisplayLabel($0) }
            lines.append("- Split cycle (order): \(names.joined(separator: " → "))")
        }
        lines.append("- Sessions per week: \(trainingProgram.sessionsPerWeek)")
        if trainingProgram.preferredWeekdays.isEmpty {
            lines.append("- Preferred training days: (none — app uses Mon–Fri pool for defaults)")
        } else {
            let wdNames = trainingProgram.preferredWeekdays.sorted().map { Self.weekdayLabel($0, calendar: cal) }
            lines.append("- Preferred weekdays: \(wdNames.joined(separator: ", "))")
        }
        lines.append("- Rotation anchor (local day): \(trainingProgram.anchorDayKey)")
        lines.append("- Day overrides: \(trainingProgram.dayOverrides.count) entries; week overrides: \(trainingProgram.weekOverrides.count) weeks")
        lines.append("")

        lines.append("## Concrete workouts (\(userWorkouts.count))")
        for w in userWorkouts {
            lines.append("### \(w.name)")
            if w.exercises.isEmpty {
                lines.append("- (no exercises)")
                continue
            }
            for we in w.exercises {
                let exName = resolvedDisplayName(for: we.exercise)
                let muscles = we.exercise.targetedMuscles.prefix(4).map(\.rawValue).joined(separator: ", ")
                lines.append("- \(exName): \(we.recommendedSets)×\(we.recommendedReps), rest \(we.defaultRestTime)s — muscles: \(muscles)")
            }
        }
        lines.append("")

        lines.append("## Slot templates (\(userWorkoutTemplates.count))")
        for t in userWorkoutTemplates {
            lines.append("### \(t.name) (blueprint)")
            if t.slots.isEmpty {
                lines.append("- (no slots yet)")
                continue
            }
            for s in t.slots {
                let muscles = s.targetedMuscles.prefix(4).map(\.rawValue).joined(separator: ", ")
                let role = s.exerciseRole?.rawValue ?? "any"
                let pat = s.movementPattern?.rawValue ?? "any"
                lines.append("- \(s.label): \(s.recommendedSets)×\(s.recommendedReps), rest \(s.defaultRestTime)s — muscles: \(muscles), role: \(role), pattern: \(pat)")
            }
        }
        lines.append("")

        let customExercises = globalExercises.filter(\.isCustom)
        lines.append("## Exercise library")
        lines.append("- Total exercises in library: \(globalExercises.count) (\(customExercises.count) custom)")
        lines.append("")

        let sortedSessions = completedSessions.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
        let recent = sortedSessions.prefix(12)
        lines.append("## Recent completed sessions (newest first, up to 12)")
        if recent.isEmpty {
            lines.append("- None yet")
        } else {
            for s in recent {
                let end = s.endTime ?? s.startTime
                let dateStr = end.formatted(date: .abbreviated, time: .shortened)
                let setCount = s.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
                lines.append("- \(dateStr): \(s.workout.name), \(setCount) sets logged, \(s.exerciseLogs.count) exercises")
            }
        }

        lines.append("")
        lines.append("## Rolling summary")
        lines.append("- Completed sessions in last 7 days (by end time): \(workoutsThisWeek)")

        var text = lines.joined(separator: "\n")
        if text.count > maxCharacters {
            text = String(text.prefix(maxCharacters)) + "\n… (snapshot truncated)"
        }
        return text
    }

    fileprivate static func weekdayLabel(_ weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "\(weekday)" }
        return symbols[weekday - 1]
    }
}
