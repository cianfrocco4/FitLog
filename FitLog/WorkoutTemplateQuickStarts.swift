//
//  WorkoutTemplateQuickStarts.swift
//  FitLog
//
//  Focus presets and one-tap workout templates for guided creation (library name resolution).
//

import Foundation

/// Training focus for new-workout guidance (starter exercises + default naming hints).
enum WorkoutCreationFocus: String, CaseIterable, Identifiable, Hashable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper body"
    case lower = "Lower body"
    case fullBody = "Full body"
    case custom = "Custom (blank)"

    var id: String { rawValue }

    /// Suggested default workout name when user leaves the name field generic.
    var suggestedWorkoutName: String {
        switch self {
        case .push: return "Push day"
        case .pull: return "Pull day"
        case .legs: return "Leg day"
        case .upper: return "Upper body"
        case .lower: return "Lower body"
        case .fullBody: return "Full body"
        case .custom: return "New workout"
        }
    }

    /// Preferred bundled-library exercise names and prescriptions (resolved via `ExerciseNameResolution`).
    var starterPlanLines: [(name: String, sets: Int, reps: String)] {
        switch self {
        case .push:
            return [
                ("Barbell Bench Press", 4, "6-10"),
                ("Overhead Barbell Press", 3, "8-12"),
                ("Incline Dumbbell Press", 3, "8-12"),
                ("Lateral Raise", 3, "12-15"),
                ("Tricep Pushdown", 3, "10-15")
            ]
        case .pull:
            return [
                ("Pull-Up", 4, "6-10"),
                ("Bent-Over Barbell Row", 4, "6-10"),
                ("Seated Cable Row", 3, "8-12"),
                ("Face Pull", 3, "12-15"),
                ("Barbell Bicep Curl", 3, "8-12")
            ]
        case .legs:
            return [
                ("Back Squat (High Bar)", 4, "6-10"),
                ("Romanian Deadlift", 3, "8-12"),
                ("Leg Press", 3, "10-12"),
                ("Leg Extension", 3, "12-15"),
                ("Lying Leg Curl", 3, "10-15"),
                ("Standing Calf Raise", 3, "12-15")
            ]
        case .upper:
            return [
                ("Barbell Bench Press", 4, "6-10"),
                ("Lat Pulldown (Wide Grip)", 3, "8-12"),
                ("Overhead Barbell Press", 3, "8-12"),
                ("Seated Cable Row", 3, "8-12"),
                ("Lateral Raise", 3, "12-15")
            ]
        case .lower:
            return [
                ("Back Squat (High Bar)", 4, "6-10"),
                ("Romanian Deadlift", 3, "8-12"),
                ("Leg Press", 3, "10-12"),
                ("Bulgarian Split Squat", 3, "8-10"),
                ("Standing Calf Raise", 3, "12-15")
            ]
        case .fullBody:
            return [
                ("Back Squat (High Bar)", 3, "8-10"),
                ("Barbell Bench Press", 3, "8-10"),
                ("Bent-Over Barbell Row", 3, "8-10"),
                ("Overhead Barbell Press", 3, "8-12"),
                ("Romanian Deadlift", 2, "8-12")
            ]
        case .custom:
            return []
        }
    }

    /// Match focus from free-text (workout title) for heuristics / AI fallback.
    static func infer(fromWorkoutTitle title: String) -> WorkoutCreationFocus? {
        let t = ExerciseNameResolution.normalizationKey(title)
        if t.contains("push") { return .push }
        if t.contains("pull") { return .pull }
        if t.contains("leg") { return .legs }
        if t.contains("upper") { return .upper }
        if t.contains("lower") { return .lower }
        if t.contains("full") && t.contains("body") { return .fullBody }
        return nil
    }
}

/// Named quick-start templates (one-tap create + exercises).
struct WorkoutQuickStartTemplate: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let defaultWorkoutName: String
    let lines: [(name: String, sets: Int, reps: String)]

    static let all: [WorkoutQuickStartTemplate] = [
        WorkoutQuickStartTemplate(
            id: "push_a",
            displayName: "Push A",
            subtitle: "Chest, shoulders, triceps",
            defaultWorkoutName: "Push A",
            lines: WorkoutCreationFocus.push.starterPlanLines
        ),
        WorkoutQuickStartTemplate(
            id: "pull_a",
            displayName: "Pull A",
            subtitle: "Back, biceps, rear delts",
            defaultWorkoutName: "Pull A",
            lines: WorkoutCreationFocus.pull.starterPlanLines
        ),
        WorkoutQuickStartTemplate(
            id: "legs_a",
            displayName: "Legs A",
            subtitle: "Squat, hinge, accessories",
            defaultWorkoutName: "Legs A",
            lines: WorkoutCreationFocus.legs.starterPlanLines
        ),
        WorkoutQuickStartTemplate(
            id: "upper",
            displayName: "Upper",
            subtitle: "Balanced upper session",
            defaultWorkoutName: "Upper body",
            lines: WorkoutCreationFocus.upper.starterPlanLines
        ),
        WorkoutQuickStartTemplate(
            id: "lower",
            displayName: "Lower",
            subtitle: "Squat & hinge focused",
            defaultWorkoutName: "Lower body",
            lines: WorkoutCreationFocus.lower.starterPlanLines
        ),
        WorkoutQuickStartTemplate(
            id: "full_body",
            displayName: "Full body",
            subtitle: "Compound full-body session",
            defaultWorkoutName: "Full body",
            lines: WorkoutCreationFocus.fullBody.starterPlanLines
        )
    ]
}

enum WorkoutStarterResolution {
    /// Offline suggestions to add to an existing workout (by title keyword + library).
    static func heuristicExercisesToAdd(to workout: Workout, library: [Exercise]) -> [(exercise: Exercise, sets: Int, reps: String)] {
        let existing = Set(workout.exercises.compactMap { $0.exerciseId })
        let focus = WorkoutCreationFocus.infer(fromWorkoutTitle: workout.name) ?? .fullBody
        return resolvedStarters(focus: focus, library: library).filter { !existing.contains($0.exercise.id) }
    }

    /// Resolves starter lines to linked library exercises (skips unresolved names).
    static func resolvedStarters(
        focus: WorkoutCreationFocus,
        library: [Exercise]
    ) -> [(exercise: Exercise, sets: Int, reps: String)] {
        resolvedLines(focus.starterPlanLines, library: library)
    }

    static func resolvedTemplate(
        _ template: WorkoutQuickStartTemplate,
        library: [Exercise]
    ) -> [(exercise: Exercise, sets: Int, reps: String)] {
        resolvedLines(template.lines, library: library)
    }

    private static func resolvedLines(
        _ lines: [(name: String, sets: Int, reps: String)],
        library: [Exercise]
    ) -> [(exercise: Exercise, sets: Int, reps: String)] {
        var out: [(Exercise, Int, String)] = []
        var seenIds = Set<UUID>()
        for line in lines {
            guard let result = ExerciseNameResolution.resolve(planName: line.name, library: library) else { continue }
            guard case .linked(let ex) = result else { continue }
            if seenIds.insert(ex.id).inserted {
                out.append((ex, line.sets, line.reps))
            }
        }
        return out
    }
}
