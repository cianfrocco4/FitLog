//
//  CoachGoalProgramming.swift
//  FitLog
//
//  Concrete programming recipes per Guided Coach primary goal.
//  Consumed by CoachRecommendationEngine and generation prompts.
//

import Foundation

struct CoachGoalProgramming: Equatable, Sendable {
    let goal: CoachGoalPick
    let defaultWeeks: Int
    let intensityStyle: String
    let progressionStyle: String
    let deloadPreference: String
    let repBias: String
    let restBias: String
    let accessoryDensity: String
    let cardioDensity: String
    let impactTeaser: String
    let programmingDirective: String

    static func resolve(from primaryGoal: String, experienceLevel: String) -> CoachGoalProgramming {
        let pick = CoachGoalPick.allCases.first { $0.rawValue == primaryGoal }
            ?? CoachGoalPick.allCases.first { primaryGoal.localizedCaseInsensitiveContains($0.rawValue) }
            ?? inferredPick(from: primaryGoal)
        return recipe(for: pick, experienceLevel: experienceLevel)
    }

    static func recipe(for goal: CoachGoalPick, experienceLevel: String) -> CoachGoalProgramming {
        let isBeginner = experienceLevel.lowercased().contains("beginner")
        let isAdvanced = experienceLevel.lowercased().contains("advanced")

        switch goal {
        case .buildMuscle:
            return CoachGoalProgramming(
                goal: goal,
                defaultWeeks: isBeginner ? 8 : 12,
                intensityStyle: "Moderate-heavy hypertrophy (RPE ~7–9)",
                progressionStyle: "Double progression (reps then weight)",
                deloadPreference: isAdvanced
                    ? "Lighter week about every 4th week"
                    : "Deload when I feel run-down",
                repBias: "6–12 reps on compounds; 8–15 on accessories",
                restBias: "90–180s compounds; 60–90s accessories",
                accessoryDensity: "High — plenty of isolation for lagging muscles",
                cardioDensity: "Light finishers only; protect lifting recovery",
                impactTeaser: "Higher volume, 6–12 reps, finishers for light conditioning.",
                programmingDirective: """
                PRIMARY GOAL: Build muscle & size — hypertrophy-first programming. \
                Prefer 6–12 reps on compounds and 8–15 on accessories, moderate-heavy loads (RPE 7–9), \
                double progression, and enough weekly sets for growth. Cardio should be short finishers \
                or easy Zone 2 so it does not steal recovery from lifting.
                """
            )

        case .strength:
            return CoachGoalProgramming(
                goal: goal,
                defaultWeeks: isBeginner ? 8 : 12,
                intensityStyle: "Heavier loads, lower reps",
                progressionStyle: isBeginner
                    ? "Linear / add weight when form is solid"
                    : "Linear on main lifts; double progression on accessories",
                deloadPreference: isAdvanced
                    ? "Lighter week about every 4th week"
                    : "Deload when I feel run-down",
                repBias: "3–6 reps on main lifts; 6–10 on secondary compounds",
                restBias: "2–4 minutes on main lifts; 90–150s elsewhere",
                accessoryDensity: "Moderate — support main lifts without junk volume",
                cardioDensity: "Minimal finishers; keep legs fresh for heavy work",
                impactTeaser: "Heavier loads, lower reps, longer rests on main lifts.",
                programmingDirective: """
                PRIMARY GOAL: Get stronger — strength-first programming. \
                Emphasize low-rep compounds (3–6), longer rest, progressive overload on squat/hinge/press/pull, \
                and keep accessory volume supportive rather than exhausting. Cardio stays light so it does not \
                interfere with heavy sessions.
                """
            )

        case .fatLoss:
            return CoachGoalProgramming(
                goal: goal,
                defaultWeeks: 8,
                intensityStyle: "Moderate loads, controlled reps (RPE ~7–8)",
                progressionStyle: "Double progression (reps then weight)",
                deloadPreference: "Deload when I feel run-down",
                repBias: "8–15 reps; density supersets where recovery allows",
                restBias: "60–90s to keep density high without sloppy form",
                accessoryDensity: "Moderate-high with efficient pairings",
                cardioDensity: "Meaningful mixed cardio — finishers plus dedicated days when schedule allows",
                impactTeaser: "Training density plus mixed cardio for fat loss and conditioning.",
                programmingDirective: """
                PRIMARY GOAL: Fat loss / conditioning — preserve muscle while raising weekly energy expenditure. \
                Use moderate loads (RPE 7–8), 8–15 reps, efficient rest, and include both lifting density and \
                cardio (finishers and/or dedicated days). Avoid ultra-low-rep strength specialization.
                """
            )

        case .performance:
            return CoachGoalProgramming(
                goal: goal,
                defaultWeeks: isBeginner ? 8 : 10,
                intensityStyle: "Athletic mix — power + strength + conditioning",
                progressionStyle: isBeginner
                    ? "Linear / add weight when form is solid"
                    : "Linear on main lifts; double progression on accessories",
                deloadPreference: isAdvanced
                    ? "Lighter week about every 4th week"
                    : "Deload when I feel run-down",
                repBias: "Power/strength compounds 3–6; supportive work 6–12",
                restBias: "Full recovery on explosive/strength work; shorter on accessories",
                accessoryDensity: "Sport-supportive — quality over volume",
                cardioDensity: "Dedicated conditioning days or mixed athletic cardio",
                impactTeaser: "Power, strength, and sport-minded conditioning.",
                programmingDirective: """
                PRIMARY GOAL: Athletic / sport performance — blend strength, power, and conditioning. \
                Prioritize quality compounds, explosive intent where safe, and structured conditioning. \
                Honor any priority lifts or sport notes. Keep sessions athletic rather than pure bodybuilding volume.
                """
            )

        case .general:
            return CoachGoalProgramming(
                goal: goal,
                defaultWeeks: 8,
                intensityStyle: "Balanced (mix of heavy and moderate)",
                progressionStyle: isBeginner
                    ? "Linear / add weight when form is solid"
                    : "Double progression (reps then weight)",
                deloadPreference: "Deload when I feel run-down",
                repBias: "Mixed 5–12 reps across the week",
                restBias: "Standard rest — enough to keep form crisp",
                accessoryDensity: "Balanced full-body coverage",
                cardioDensity: "Light finishers for general health",
                impactTeaser: "Balanced strength, muscle, and general health.",
                programmingDirective: """
                PRIMARY GOAL: General fitness & health — balanced full-body programming. \
                Mix moderate strength and hypertrophy work, keep complexity appropriate for experience, \
                and include light cardio for health without specializing hard into one outcome.
                """
            )
        }
    }

    private static func inferredPick(from raw: String) -> CoachGoalPick {
        let lower = raw.lowercased()
        if lower.contains("muscle") || lower.contains("hypertrophy") || lower.contains("size") {
            return .buildMuscle
        }
        if lower.contains("strong") || lower.contains("strength") {
            return .strength
        }
        if lower.contains("fat") || lower.contains("condition") || lower.contains("cut") {
            return .fatLoss
        }
        if lower.contains("athletic") || lower.contains("performance") || lower.contains("sport") {
            return .performance
        }
        return .general
    }
}
