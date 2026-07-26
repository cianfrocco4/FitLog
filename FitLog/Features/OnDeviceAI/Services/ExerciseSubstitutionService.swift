//
//  ExerciseSubstitutionService.swift
//  FitLog
//
//  Deterministic muscle/equipment filter first; optional on-device ranking.
//

import Foundation

enum ExerciseSubstitutionService {
    /// Primary filter: overlapping targeted muscles; prefer same movement pattern / role.
    static func candidates(
        for source: Exercise,
        in library: [Exercise],
        limit: Int = 8
    ) -> [Exercise] {
        let sourceMuscles = Set(source.targetedMuscles)
        let scored: [(Exercise, Int)] = library.compactMap { candidate in
            guard candidate.id != source.id else { return nil }
            guard candidate.modality == source.modality || source.modality == .strength else { return nil }
            let sharedMuscles = Set(candidate.targetedMuscles).intersection(sourceMuscles).count
            guard sharedMuscles > 0 else { return nil }
            var score = sharedMuscles * 10
            if candidate.movementPattern != nil, candidate.movementPattern == source.movementPattern {
                score += 5
            }
            if candidate.exerciseRole == source.exerciseRole {
                score += 2
            }
            return (candidate, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    @MainActor
    static func propose(
        source: Exercise,
        library: [Exercise],
        isPremium: Bool,
        router: AIRoutingService
    ) async -> [ExerciseSubstitutionCandidate] {
        let filtered = candidates(for: source, in: library)
        guard !filtered.isEmpty else { return [] }

        let baseline = filtered.prefix(3).map { ex in
            ExerciseSubstitutionCandidate(
                id: ex.id,
                exerciseName: ex.name,
                rationale: "Matches \(ex.targetedMuscles.prefix(2).map(\.rawValue).joined(separator: ", "))"
            )
        }

        guard isPremium, router.onDeviceAvailability.isAvailable else {
            return Array(baseline)
        }

        let list = filtered.map(\.name).joined(separator: ", ")
        let prompt = """
        Source exercise: \(source.name)
        Primary muscles: \(source.targetedMuscles.map(\.rawValue).joined(separator: ", "))
        Allowed library names ONLY: \(list)
        Rank up to 3 substitutes.
        """
        do {
            let ranked = try await router.onDeviceModel.rankSubstitutions(prompt: prompt)
            let byName = Dictionary(uniqueKeysWithValues: filtered.map { ($0.name.lowercased(), $0) })
            let mapped: [ExerciseSubstitutionCandidate] = ranked.compactMap { item in
                guard let match = byName[item.exerciseName.lowercased()] else { return nil }
                return ExerciseSubstitutionCandidate(
                    id: match.id,
                    exerciseName: match.name,
                    rationale: item.rationale
                )
            }
            if !mapped.isEmpty {
                AnalyticsService.shared.track(.onDeviceAIUsed, properties: ["feature": "substitutions"])
                return Array(mapped.prefix(3))
            }
        } catch {
            AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                "feature": "substitutions",
                "reason": error.localizedDescription
            ])
        }
        return Array(baseline)
    }
}
