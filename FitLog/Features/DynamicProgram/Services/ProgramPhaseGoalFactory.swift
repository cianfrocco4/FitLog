//
//  ProgramPhaseGoalFactory.swift
//  FitLog
//
//  Builds and re-normalizes phase process goals from block focus + schedule.
//

import Foundation

enum ProgramPhaseGoalFactory {
    /// Attaches or refreshes auto goals on every block. Preserves `.userSet` target values.
    static func attachingAutoGoals(
        to program: DynamicProgram,
        primaryGoal: CoachGoalPick? = nil
    ) -> DynamicProgram {
        var copy = program
        for i in copy.blocks.indices {
            copy.blocks[i].phaseGoal = make(
                for: copy.blocks[i],
                sessionsPerWeek: copy.defaultSessionsPerWeek,
                primaryGoal: primaryGoal,
                existing: copy.blocks[i].phaseGoal
            )
        }
        return copy
    }

    /// Suggested goal for a single block. When `existing` has `.userSet` targets, those values are kept.
    static func make(
        for block: ProgramBlock,
        sessionsPerWeek: Int,
        primaryGoal: CoachGoalPick? = nil,
        existing: ProgramPhaseGoal? = nil
    ) -> ProgramPhaseGoal {
        let programming = primaryGoal.map { CoachGoalProgramming.recipe(for: $0, experienceLevel: "") }
        let autoTitle = goalTitle(for: block, programming: programming)
        let autoSummary = goalSummary(for: block, programming: programming, sessionsPerWeek: sessionsPerWeek)
        let autoTargets = suggestedTargets(for: block, sessionsPerWeek: sessionsPerWeek)
        let merged = mergeTargets(auto: autoTargets, existing: existing?.targets ?? [])
        let rationale = programming?.impactTeaser
        let preserveCopy = existing?.copyIsUserSet == true
        let title = preserveCopy ? (preservedCopy(existing?.title) ?? autoTitle) : autoTitle
        let summary = preserveCopy ? (preservedCopy(existing?.summary) ?? autoSummary) : autoSummary
        return ProgramPhaseGoal(
            title: title,
            summary: summary,
            targets: merged,
            coachRationale: existing?.coachRationale ?? rationale,
            copyIsUserSet: preserveCopy
        )
    }

    /// Preview line for Coach plan preview before generation (no templates yet).
    static func previewLine(
        focus: BlockFocus,
        durationWeeks: Int,
        sessionsPerWeek: Int,
        primaryGoal: CoachGoalPick?,
        isDeload: Bool
    ) -> String {
        if isDeload || focus.kind == .deload {
            return "Recover — lighter sessions for \(durationWeeks) wk · keep \(sessionsPerWeek)×/week moving"
        }
        let programming = primaryGoal.map { CoachGoalProgramming.recipe(for: $0, experienceLevel: "") }
        let focusLabel = focus.kind.userFriendlyShortLabel
        let teaser = programming?.impactTeaser ?? focusLabel
        return "\(focusLabel) — train \(sessionsPerWeek)×/week · \(teaser)"
    }

    // MARK: - Targets

    static func suggestedTargets(for block: ProgramBlock, sessionsPerWeek: Int) -> [ProgramGoalTarget] {
        let sessions = max(1, min(7, sessionsPerWeek))
        var hardSets = ProgramVolumeMath.plannedWeeklyHardSets(for: block)
        if hardSets <= 0 {
            // Fallback when templates are empty (pre-generate / broken block).
            hardSets = sessions * 12
        }
        let cardioMinutes = ProgramVolumeMath.plannedWeeklyCardioMinutes(for: block)
        let includeCardio = shouldIncludeCardio(block: block, plannedMinutes: cardioMinutes)

        var targets: [ProgramGoalTarget] = [
            ProgramGoalTarget(
                kind: .sessionsPerWeek,
                value: Double(sessions),
                tolerance: 0,
                isPrimary: true,
                source: .auto
            ),
            ProgramGoalTarget(
                kind: .weeklyHardSets,
                value: Double(hardSets),
                tolerance: max(1, Double(hardSets) * 0.1),
                isPrimary: false,
                source: .auto
            ),
        ]
        if includeCardio {
            let minutes = max(cardioMinutes, estimatedCardioFallback(for: block))
            targets.append(
                ProgramGoalTarget(
                    kind: .weeklyCardioMinutes,
                    value: Double(minutes),
                    tolerance: max(5, Double(minutes) * 0.15),
                    isPrimary: false,
                    source: .auto
                )
            )
        }
        return targets
    }

    // MARK: - Copy

    private static func goalTitle(for block: ProgramBlock, programming: CoachGoalProgramming?) -> String {
        if block.isDeloadBlock || block.focus.kind == .deload {
            return "Recover & reset"
        }
        if let programming {
            switch programming.goal {
            case .buildMuscle: return block.focus.kind == .strength ? "Get stronger" : "Build muscle"
            case .strength: return "Get stronger"
            case .fatLoss: return "Fat loss & conditioning"
            case .performance: return "Athletic performance"
            case .general: return block.focus.kind.userFriendlyShortLabel
            }
        }
        return block.focus.kind.userFriendlyShortLabel
    }

    private static func goalSummary(
        for block: ProgramBlock,
        programming: CoachGoalProgramming?,
        sessionsPerWeek: Int
    ) -> String {
        let sessions = max(1, min(7, sessionsPerWeek))
        if block.isDeloadBlock || block.focus.kind == .deload {
            return "Keep moving \(sessions)×/week with reduced volume so you come back fresh."
        }
        let hardSets = ProgramVolumeMath.plannedWeeklyHardSets(for: block)
        let setPart = hardSets > 0 ? " and about \(hardSets) hard sets" : ""
        if let teaser = programming?.impactTeaser, !teaser.isEmpty {
            return "Train \(sessions)×/week\(setPart). \(teaser)"
        }
        return "Train \(sessions)×/week\(setPart) with a \(block.focus.kind.userFriendlyShortLabel.lowercased()) focus."
    }

    private static func shouldIncludeCardio(block: ProgramBlock, plannedMinutes: Int) -> Bool {
        if plannedMinutes > 0 { return true }
        switch block.focus.kind {
        case .endurance, .hybrid: return true
        default: break
        }
        if let pref = block.cardioPreference, pref != .none { return true }
        return false
    }

    private static func estimatedCardioFallback(for block: ProgramBlock) -> Int {
        let config = CardioProgramConfiguration(
            goal: block.cardioGoal ?? .generalHealth,
            preference: block.cardioPreference ?? .mixed,
            dedicatedDayCount: block.cardioDedicatedDayCount ?? 2,
            finisherDurationMinutes: block.cardioFinisherDurationMinutes ?? 10,
            finisherZone: block.cardioFinisherZone ?? .zone2,
            weeklyProgressionMinutes: block.cardioWeeklyProgressionMinutes ?? 5
        )
        return max(20, config.estimatedWeeklyMinutes)
    }

    private static func mergeTargets(auto: [ProgramGoalTarget], existing: [ProgramGoalTarget]) -> [ProgramGoalTarget] {
        let userByKind = Dictionary(
            uniqueKeysWithValues: existing.filter { $0.source == .userSet }.map { ($0.kind, $0) }
        )
        return auto.map { suggested in
            if let user = userByKind[suggested.kind] {
                return ProgramGoalTarget(
                    kind: suggested.kind,
                    value: user.value,
                    tolerance: user.tolerance ?? suggested.tolerance,
                    isPrimary: suggested.isPrimary,
                    source: .userSet
                )
            }
            return suggested
        }
    }

    private static func preservedCopy(_ value: String?) -> String? {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return nil
        }
        return t
    }
}
