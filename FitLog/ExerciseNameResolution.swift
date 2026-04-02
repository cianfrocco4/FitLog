//
//  ExerciseNameResolution.swift
//  FitLog
//
//  Maps AI / plan exercise name strings onto library exercises (exact, normalized, or fuzzy)
//  or signals that a new custom exercise should be created.
//

import Foundation

enum ExerciseNameResolutionResult: Equatable {
    case linked(Exercise)
    case createCustom(displayName: String)
}

enum ExerciseNameResolution {
    /// Normalized key for deduplication within a single apply and for fuzzy comparison.
    static func dedupeKey(forPlanName name: String) -> String {
        normalizationKey(name)
    }

    static func resolve(planName: String, library: [Exercise]) -> ExerciseNameResolutionResult? {
        let trimmed = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = normalizationKey(trimmed)

        if let ex = library.first(where: { normalizationKey($0.name) == key }) {
            return .linked(ex)
        }

        var scored: [(Exercise, Double)] = library.map { ex in
            (ex, similarity(planKey: key, candidateName: ex.name))
        }
        scored.sort { $0.1 > $1.1 }

        guard let top = scored.first else {
            return .createCustom(displayName: trimmed)
        }

        let minScore = 0.82
        let minGap = 0.04
        let secondScore = scored.dropFirst().first?.1 ?? 0

        if top.1 >= minScore, (top.1 - secondScore) >= minGap {
            return .linked(top.0)
        }

        return .createCustom(displayName: trimmed)
    }

    // MARK: - Muscle group (slot targets)

    /// Best-effort parse of slot muscle strings to `MuscleGroup`, including fuzzy match on display names.
    static func resolveMuscleGroups(from rawStrings: [String]) -> [MuscleGroup] {
        var out: [MuscleGroup] = []
        for raw in rawStrings {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let m = resolveSingleMuscle(trimmed) {
                out.append(m)
            }
        }
        return out
    }

    private static func resolveSingleMuscle(_ trimmed: String) -> MuscleGroup? {
        let key = normalizationKey(trimmed)
        if let exact = MuscleGroup.allCases.first(where: { normalizationKey($0.rawValue) == key }) {
            return exact
        }
        var scored: [(MuscleGroup, Double)] = MuscleGroup.allCases.map { m in
            (m, similarity(planKey: key, candidateName: m.rawValue))
        }
        scored.sort { $0.1 > $1.1 }
        guard let top = scored.first else { return nil }
        let minScore = 0.75
        let minGap = 0.03
        let second = scored.dropFirst().first?.1 ?? 0
        if top.1 >= minScore, (top.1 - second) >= minGap {
            return top.0
        }
        return nil
    }

    // MARK: - Internals

    static func normalizationKey(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.lowercased()
    }

    private static func similarity(planKey: String, candidateName: String) -> Double {
        let cKey = normalizationKey(candidateName)
        guard !planKey.isEmpty, !cKey.isEmpty else { return 0 }
        if planKey == cKey { return 1 }
        let d = levenshtein(planKey, cKey)
        let maxLen = max(planKey.count, cKey.count)
        return 1 - Double(d) / Double(maxLen)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
