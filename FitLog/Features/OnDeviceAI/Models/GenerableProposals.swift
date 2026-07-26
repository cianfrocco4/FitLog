//
//  GenerableProposals.swift
//  FitLog
//
//  Foundation Models guided-generation shapes (iOS 26+).
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A single concrete change to today's training plan.")
struct GenerableDailyChange {
    @Guide(description: "One of: makeLighter, markRest, keepAsPlanned, swapFocusNote")
    var kind: String
    @Guide(description: "Short plain-language description of the change")
    var detail: String
}

@available(iOS 26.0, *)
@Generable(description: "Proposed adjustment to today's workout based on readiness and user notes.")
struct GenerableDailyAdjustment {
    @Guide(description: "One-sentence summary of the recommendation")
    var summary: String
    @Guide(description: "1-3 concrete plan changes")
    var changes: [GenerableDailyChange]
    @Guide(description: "Plain-language why, referencing readiness or soreness when relevant")
    var rationale: String
    @Guide(description: "Always true; acknowledges this is general fitness coaching not medical advice")
    var disclaimerAck: Bool
}

@available(iOS 26.0, *)
@Generable(description: "Weekly training insight for a lifter.")
struct GenerableWeeklyInsight {
    @Guide(description: "Short title for the week in review")
    var title: String
    @Guide(description: "2-4 sentence narrative of the week")
    var narrative: String
    @Guide(description: "Up to 3 positive highlights")
    var highlights: [String]
    @Guide(description: "Up to 3 risks or recovery concerns")
    var risks: [String]
    @Guide(description: "1-3 concrete next actions")
    var nextActions: [String]
}

@available(iOS 26.0, *)
@Generable(description: "Ranked exercise substitution with a short why.")
struct GenerableSubstitution {
    @Guide(description: "Exact library exercise name to use as a substitute")
    var exerciseName: String
    @Guide(description: "Why this swap fits muscles and constraints")
    var rationale: String
}

@available(iOS 26.0, *)
@Generable(description: "List of exercise substitutions.")
struct GenerableSubstitutionList {
    @Guide(description: "Up to 3 ranked substitutes")
    var items: [GenerableSubstitution]
}

@available(iOS 26.0, *)
@Generable(description: "Short form cues for an exercise.")
struct GenerableFormCues {
    @Guide(description: "2-4 concise form cues")
    var cues: [String]
}

@available(iOS 26.0, *)
enum GenerableMapping {
    static func dailyAdjustment(from generated: GenerableDailyAdjustment) -> DailyAdjustmentProposal {
        let changes = generated.changes.compactMap { change -> DailyAdjustmentChange? in
            guard let kind = DailyAdjustActionKind(rawValue: change.kind) else { return nil }
            return DailyAdjustmentChange(kind: kind, detail: change.detail)
        }
        return DailyAdjustmentProposal(
            summary: generated.summary,
            changes: changes.isEmpty
                ? [DailyAdjustmentChange(kind: .keepAsPlanned, detail: "Keep today's plan as scheduled.")]
                : changes,
            rationale: generated.rationale,
            disclaimerAck: generated.disclaimerAck,
            routeUsed: .onDevice
        )
    }

    static func weeklyInsight(from generated: GenerableWeeklyInsight, weekKey: String) -> WeeklyInsight {
        WeeklyInsight(
            weekKey: weekKey,
            title: generated.title,
            narrative: generated.narrative,
            highlights: Array(generated.highlights.prefix(3)),
            risks: Array(generated.risks.prefix(3)),
            nextActions: Array(generated.nextActions.prefix(3)),
            routeUsed: .onDevice,
            generatedAt: .now
        )
    }
}
#endif
