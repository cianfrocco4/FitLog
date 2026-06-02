//
//  ExerciseSwapSimilarity.swift
//  FitLog
//
//  Shared ranking for exercise swap pickers (quick swap + template swap).
//

import Foundation

enum ExerciseSwapSimilarity {
    static func score(candidate: Exercise, baseline: Exercise, slotMuscleMatch: Bool) -> Int {
        var s = 0
        switch (baseline.movementPattern, candidate.movementPattern) {
        case let (b?, c?) where b == c:
            s += 100
        case (nil, nil):
            s += 8
        default:
            break
        }
        if candidate.exerciseRole == baseline.exerciseRole {
            s += 50
        }
        let bM = Set(baseline.targetedMuscles)
        let cM = Set(candidate.targetedMuscles)
        let overlap = bM.intersection(cM)
        s += min(overlap.count * 18, 72)
        if let bf = baseline.targetedMuscles.first, let cf = candidate.targetedMuscles.first, bf == cf {
            s += 38
        }
        if slotMuscleMatch {
            s += 45
        }
        return s
    }

    static func scoreFromSlotOnly(candidate: Exercise, slot: TemplateSlot, slotMuscleMatch: Bool) -> Int {
        var s = 0
        if slotMuscleMatch { s += 55 }
        if let sp = slot.movementPattern, let cp = candidate.movementPattern, sp == cp {
            s += 100
        }
        if let sr = slot.exerciseRole, candidate.exerciseRole == sr {
            s += 50
        }
        let sM = Set(slot.targetedMuscles)
        let cM = Set(candidate.targetedMuscles)
        s += min(sM.intersection(cM).count * 18, 72)
        if let sf = slot.targetedMuscles.first, let cf = candidate.targetedMuscles.first, sf == cf {
            s += 38
        }
        return s
    }

    static func tierLabel(score: Int) -> String {
        switch score {
        case 165...:
            return "Strong matches"
        case 98..<165:
            return "Good matches"
        case 42..<98:
            return "Partial matches"
        default:
            return "Weaker matches"
        }
    }

    static func fitBadge(score: Int) -> String? {
        switch score {
        case 165...: return "Strong fit"
        case 98..<165: return "Good fit"
        case 42..<98: return "Partial fit"
        default: return nil
        }
    }

    static func matchSummary(
        candidate: Exercise,
        baseline: Exercise?,
        slot: TemplateSlot?,
        slotMuscleMatch: Bool
    ) -> String {
        var parts: [String] = []
        if let b = baseline {
            if let bp = b.movementPattern, let cp = candidate.movementPattern, bp == cp {
                parts.append("Same pattern (\(bp.rawValue))")
            }
            if b.exerciseRole == candidate.exerciseRole {
                parts.append("Same role (\(b.exerciseRole.rawValue))")
            }
            let shared = Set(b.targetedMuscles).intersection(Set(candidate.targetedMuscles))
            if !shared.isEmpty {
                let names = shared.map(\.rawValue).sorted().joined(separator: ", ")
                parts.append("Shared muscles: \(names)")
            }
        } else if let slot {
            if let sp = slot.movementPattern, let cp = candidate.movementPattern, sp == cp {
                parts.append("Matches slot pattern (\(sp.rawValue))")
            }
            if let sr = slot.exerciseRole, candidate.exerciseRole == sr {
                parts.append("Matches slot role (\(sr.rawValue))")
            }
            let shared = Set(slot.targetedMuscles).intersection(Set(candidate.targetedMuscles))
            if !shared.isEmpty {
                let names = shared.map(\.rawValue).sorted().joined(separator: ", ")
                parts.append("Overlaps slot muscles: \(names)")
            }
        }
        if slotMuscleMatch {
            parts.append("Fits slot muscle filter")
        }
        if parts.isEmpty {
            return "Different movement profile"
        }
        return parts.joined(separator: " · ")
    }
}
