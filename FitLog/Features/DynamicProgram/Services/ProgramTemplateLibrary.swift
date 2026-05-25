//
//  ProgramTemplateLibrary.swift
//  FitLog
//
//  Curated one-tap program presets for Quick Start.
//

import Foundation

enum ProgramTemplateGoalCategory: String, CaseIterable, Identifiable, Sendable {
    case muscle
    case strength
    case fatLoss
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .muscle: return "Muscle"
        case .strength: return "Strength"
        case .fatLoss: return "Fat loss"
        case .general: return "General"
        }
    }

    var iconName: String {
        switch self {
        case .muscle: return "figure.strengthtraining.traditional"
        case .strength: return "dumbbell.fill"
        case .fatLoss: return "flame.fill"
        case .general: return "heart.fill"
        }
    }
}

struct CuratedProgramTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let goalCategory: ProgramTemplateGoalCategory
    let difficulty: String
    let sessionsPerWeek: Int
    let totalWeeks: Int
    let splitLabel: String
    let iconName: String
    let primaryGoal: String
    let splitPreference: String
    let experienceLevel: String
    let programStructure: DynamicProgramBuilderViewModel.ProgramStructurePreset
    let isPeriodized: Bool

    func buildRequest(programName: String? = nil) -> DynamicProgramGenerationRequest {
        var input = WorkoutSplitBuilderStructuredInput(
            primaryGoal: primaryGoal,
            equipment: "Full gym (machines + free weights)",
            splitPreference: splitPreference,
            experienceLevel: experienceLevel,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: [],
            limitationsNotes: "",
            additionalNotes: "Quick Start template: \(name).",
            sessionDurationMinutes: 60,
            intensityStyle: goalCategory == .strength
                ? "Heavier loads, lower reps"
                : "Balanced (mix of heavy and moderate)",
            progressionStyle: goalCategory == .strength
                ? "Linear / add weight when form is solid"
                : "Double progression (reps then weight)",
            priorityMusclesOrLiftsNotes: "",
            recoveryContextNotes: "",
            deloadPreference: totalWeeks >= 8 ? "Lighter week about every 4th week" : "Not specified",
            cardioPreference: goalCategory == .fatLoss
                ? CardioProgramPreference.mixed.rawValue
                : CardioProgramPreference.none.rawValue,
            variationMode: "Balanced variation",
            desiredWorkoutRotationLength: nil,
            variationNotes: "",
            adjustmentInstruction: nil
        )

        var request = DynamicProgramGenerationRequest(
            splitInput: input,
            programName: programName ?? name,
            isPeriodized: isPeriodized,
            blockSpecs: [],
            busyDayPolicy: .flexDay
        )

        let blockFocus: BlockFocusKind = switch goalCategory {
        case .muscle: .hypertrophy
        case .strength: .strength
        case .fatLoss: .hybrid
        case .general: .general
        }

        switch programStructure {
        case .singlePhase:
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Training",
                    focus: BlockFocus(kind: blockFocus, emphasisLabel: ""),
                    durationWeeks: totalWeeks,
                    progressionStrategy: input.resolvedProgressionStrategy()
                ),
            ]
        case .twoPhases:
            let w1 = max(1, totalWeeks / 2)
            let w2 = max(1, totalWeeks - w1)
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Phase 1: Build",
                    focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                    durationWeeks: w1,
                    progressionStrategy: .doubleProgression
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 2: Peak",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: w2,
                    progressionStrategy: .linear
                ),
            ]
        case .threePhases, .custom:
            let w1 = max(1, (totalWeeks * 2) / 5)
            let w2 = max(1, (totalWeeks * 2) / 5)
            let w3 = max(1, totalWeeks - w1 - w2)
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Phase 1: Build",
                    focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                    durationWeeks: w1,
                    progressionStrategy: .doubleProgression
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 2: Strength",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: w2,
                    progressionStrategy: .linear
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 3: Deload",
                    focus: BlockFocus(kind: .deload, emphasisLabel: ""),
                    durationWeeks: w3,
                    progressionStrategy: .doubleProgression,
                    volumeMultiplier: 0.72,
                    isDeloadBlock: true
                ),
            ]
        }

        return request
    }
}

enum ProgramTemplateLibrary {
    static let all: [CuratedProgramTemplate] = [
        CuratedProgramTemplate(
            id: "ppl-hypertrophy-4",
            name: "PPL Hypertrophy",
            subtitle: "Classic push / pull / legs for size",
            goalCategory: .muscle,
            difficulty: "Intermediate",
            sessionsPerWeek: 4,
            totalWeeks: 8,
            splitLabel: "Push / Pull / Legs",
            iconName: "arrow.triangle.2.circlepath",
            primaryGoal: "Build muscle & size",
            splitPreference: "Push / Pull / Legs",
            experienceLevel: "Intermediate",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "ppl-hypertrophy-6",
            name: "PPL Advanced",
            subtitle: "Six-day push / pull / legs split",
            goalCategory: .muscle,
            difficulty: "Advanced",
            sessionsPerWeek: 6,
            totalWeeks: 12,
            splitLabel: "Push / Pull / Legs",
            iconName: "arrow.triangle.2.circlepath",
            primaryGoal: "Build muscle & size",
            splitPreference: "Push / Pull / Legs",
            experienceLevel: "Advanced",
            programStructure: .twoPhases,
            isPeriodized: true
        ),
        CuratedProgramTemplate(
            id: "upper-lower-strength",
            name: "Upper / Lower Strength",
            subtitle: "Four-day strength-focused split",
            goalCategory: .strength,
            difficulty: "Intermediate",
            sessionsPerWeek: 4,
            totalWeeks: 8,
            splitLabel: "Upper / Lower",
            iconName: "arrow.up.arrow.down",
            primaryGoal: "Get stronger (strength focus)",
            splitPreference: "Upper / Lower",
            experienceLevel: "Intermediate",
            programStructure: .twoPhases,
            isPeriodized: true
        ),
        CuratedProgramTemplate(
            id: "full-body-beginner",
            name: "Full Body Beginner",
            subtitle: "Three full-body sessions per week",
            goalCategory: .general,
            difficulty: "Beginner",
            sessionsPerWeek: 3,
            totalWeeks: 8,
            splitLabel: "Full body",
            iconName: "figure.strengthtraining.functional",
            primaryGoal: "General fitness & health",
            splitPreference: "Full body",
            experienceLevel: "Beginner",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "full-body-intermediate",
            name: "Full Body Plus",
            subtitle: "Four-day full-body with variation",
            goalCategory: .general,
            difficulty: "Intermediate",
            sessionsPerWeek: 4,
            totalWeeks: 8,
            splitLabel: "Full body",
            iconName: "figure.strengthtraining.functional",
            primaryGoal: "General fitness & health",
            splitPreference: "Full body",
            experienceLevel: "Intermediate",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "bro-split",
            name: "Bro Split",
            subtitle: "Five-day muscle-group rotation",
            goalCategory: .muscle,
            difficulty: "Intermediate",
            sessionsPerWeek: 5,
            totalWeeks: 8,
            splitLabel: "Bro split",
            iconName: "figure.arms.open",
            primaryGoal: "Build muscle & size",
            splitPreference: "Muscle group (bro) split",
            experienceLevel: "Intermediate",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "fat-loss-conditioning",
            name: "Fat Loss & Conditioning",
            subtitle: "Hybrid strength + cardio program",
            goalCategory: .fatLoss,
            difficulty: "Intermediate",
            sessionsPerWeek: 4,
            totalWeeks: 8,
            splitLabel: "Upper / Lower + cardio",
            iconName: "figure.run",
            primaryGoal: "Fat loss / conditioning",
            splitPreference: "Upper / Lower",
            experienceLevel: "Intermediate",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "strength-linear",
            name: "Linear Strength Block",
            subtitle: "Focused four-week strength block",
            goalCategory: .strength,
            difficulty: "Advanced",
            sessionsPerWeek: 4,
            totalWeeks: 4,
            splitLabel: "Upper / Lower",
            iconName: "bolt.fill",
            primaryGoal: "Get stronger (strength focus)",
            splitPreference: "Upper / Lower",
            experienceLevel: "Advanced",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
        CuratedProgramTemplate(
            id: "periodized-12",
            name: "12-Week Periodized",
            subtitle: "Build, peak, then recover",
            goalCategory: .muscle,
            difficulty: "Advanced",
            sessionsPerWeek: 4,
            totalWeeks: 12,
            splitLabel: "Push / Pull / Legs",
            iconName: "chart.line.uptrend.xyaxis",
            primaryGoal: "Build muscle & size",
            splitPreference: "Push / Pull / Legs",
            experienceLevel: "Advanced",
            programStructure: .threePhases,
            isPeriodized: true
        ),
        CuratedProgramTemplate(
            id: "general-3x",
            name: "Balanced 3×",
            subtitle: "Simple three-day balanced program",
            goalCategory: .general,
            difficulty: "Beginner",
            sessionsPerWeek: 3,
            totalWeeks: 4,
            splitLabel: "Full body",
            iconName: "calendar",
            primaryGoal: "General fitness & health",
            splitPreference: "Full body",
            experienceLevel: "Beginner",
            programStructure: .singlePhase,
            isPeriodized: false
        ),
    ]

    static func templates(for category: ProgramTemplateGoalCategory?) -> [CuratedProgramTemplate] {
        guard let category else { return all }
        return all.filter { $0.goalCategory == category }
    }
}
