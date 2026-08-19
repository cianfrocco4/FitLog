//
//  SpotlightTourStep.swift
//  FitLog
//
//  First-run spotlight targets and copy. Persistence lives in UserPreferences.
//

import Foundation

enum SpotlightTarget: String, Hashable, Sendable {
    case firstRunHero
    case programCard
    case todayPlan
    case workoutsList
    case startWorkoutFAB
    case planTab

    /// When the preferred chrome is not on screen yet (empty Home), use this instead.
    var fallback: SpotlightTarget? {
        switch self {
        case .todayPlan: return .programCard
        case .programCard: return .firstRunHero
        case .workoutsList: return .firstRunHero
        default: return nil
        }
    }
}

enum SpotlightTourKind: String, Equatable, Sendable {
    /// After applying or opening the program builder.
    case afterProgram
    /// After creating a workout.
    case afterWorkout
    /// Skip / “I’ll explore first”.
    case explore
}

struct SpotlightTourStep: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let target: SpotlightTarget
}

enum SpotlightTourCatalog {
    static func steps(for kind: SpotlightTourKind) -> [SpotlightTourStep] {
        switch kind {
        case .afterProgram:
            return [
                SpotlightTourStep(
                    id: "today",
                    title: "This is what you train today",
                    body: "Home shows today’s planned workout once your program is on the calendar.",
                    target: .todayPlan
                ),
                SpotlightTourStep(
                    id: "start",
                    title: "Start when you’re ready",
                    body: "Tap Start workout to log sets. You can also start from today’s plan card.",
                    target: .startWorkoutFAB
                ),
                SpotlightTourStep(
                    id: "plan",
                    title: "Change your week in Plan",
                    body: "The Plan tab is your calendar — adjust days, rest, and how many sessions you want.",
                    target: .planTab
                )
            ]
        case .afterWorkout:
            return [
                SpotlightTourStep(
                    id: "library",
                    title: "Your workouts live here",
                    body: "Anything you create is saved in this list. Swipe or tap Start to train.",
                    target: .workoutsList
                ),
                SpotlightTourStep(
                    id: "start",
                    title: "Start when you’re ready",
                    body: "Tap Start workout to pick today’s session and begin logging.",
                    target: .startWorkoutFAB
                ),
                SpotlightTourStep(
                    id: "program",
                    title: "Optional: plan your week",
                    body: "Build a program when you want Home and Plan to schedule workouts for you.",
                    target: .programCard
                )
            ]
        case .explore:
            return [
                SpotlightTourStep(
                    id: "hero",
                    title: "Create something to train",
                    body: "A workout is a session you log. A program fills your week with those workouts.",
                    target: .firstRunHero
                ),
                SpotlightTourStep(
                    id: "start",
                    title: "Start workout is always here",
                    body: "Use this button anytime to create a session or begin logging.",
                    target: .startWorkoutFAB
                ),
                SpotlightTourStep(
                    id: "plan",
                    title: "Plan is your calendar",
                    body: "After you have a program or lineup, this tab shows which day you train.",
                    target: .planTab
                )
            ]
        }
    }
}
