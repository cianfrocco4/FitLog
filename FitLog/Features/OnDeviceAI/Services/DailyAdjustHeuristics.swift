//
//  DailyAdjustHeuristics.swift
//  FitLog
//
//  Deterministic fallback when on-device and cloud AI are unavailable.
//

import Foundation

enum DailyAdjustHeuristics {
    static func proposal(for context: DailyAdjustContextPack) -> DailyAdjustmentProposal {
        let score = context.readinessScore ?? 55
        let note = context.userNote.lowercased()
        let sore = note.contains("sore") || note.contains("pain") || note.contains("ache")
        let poorSleep = note.contains("sleep") || note.contains("tired") || note.contains("fatigue")

        if score < 45 || (sore && score < 60) {
            if context.hasDynamicProgram {
                return DailyAdjustmentProposal(
                    summary: "Make today lighter to match recovery.",
                    changes: [
                        DailyAdjustmentChange(
                            kind: .makeLighter,
                            detail: "Mark today as a busy/flex day so volume is reduced (~50% sets)."
                        )
                    ],
                    rationale: "Readiness is \(score)/100\(sore ? " and you noted soreness" : ""). A lighter session protects progress better than pushing through.",
                    disclaimerAck: true,
                    routeUsed: .heuristic
                )
            }
            return DailyAdjustmentProposal(
                summary: "Consider resting or swapping to a lighter day.",
                changes: [
                    DailyAdjustmentChange(
                        kind: .markRest,
                        detail: "Mark today as rest in your plan (you can undo in Plan)."
                    )
                ],
                rationale: "Without a dynamic program flex day, rest is the safest recovery option when readiness is low.",
                disclaimerAck: true,
                routeUsed: .heuristic
            )
        }

        if poorSleep || score < 55 {
            return DailyAdjustmentProposal(
                summary: "Keep the plan but reduce intensity cues.",
                changes: [
                    DailyAdjustmentChange(
                        kind: .swapFocusNote,
                        detail: "Cap effort ~1–2 RPE below usual; skip grinders and extras."
                    ),
                    DailyAdjustmentChange(
                        kind: context.hasDynamicProgram ? .makeLighter : .keepAsPlanned,
                        detail: context.hasDynamicProgram
                            ? "Optional: enable busy/flex day if the session still feels heavy."
                            : "Keep the scheduled workout with moderated effort."
                    )
                ],
                rationale: "Moderate readiness\(poorSleep ? " and sleep notes" : "") suggest training, but with brakes on volume/intensity.",
                disclaimerAck: true,
                routeUsed: .heuristic
            )
        }

        return DailyAdjustmentProposal(
            summary: "You're good to train as planned.",
            changes: [
                DailyAdjustmentChange(kind: .keepAsPlanned, detail: "Run \(context.plannedWorkoutName) as scheduled.")
            ],
            rationale: "Readiness looks solid (\(score)/100). Stick to the plan unless something feels off mid-session.",
            disclaimerAck: true,
            routeUsed: .heuristic
        )
    }
}
