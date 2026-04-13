//
//  ExerciseSearch.swift
//  FitLog
//

import Foundation

extension Exercise {
    /// Unified search: display name, canonical name, and **all** targeted muscles (not only primary).
    func matchesExerciseSearch(
        query: String,
        resolvedDisplayName: String
    ) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        if resolvedDisplayName.localizedCaseInsensitiveContains(q) { return true }
        if name.localizedCaseInsensitiveContains(q) { return true }
        return targetedMuscles.contains { $0.rawValue.localizedCaseInsensitiveContains(q) }
    }
}
