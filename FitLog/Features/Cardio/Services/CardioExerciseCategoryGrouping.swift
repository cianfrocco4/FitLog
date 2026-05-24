//
//  CardioExerciseCategoryGrouping.swift
//  FitLog
//
//  Groups cardio library exercises by `CardioActivityKind` for the Exercise Library.
//

import Foundation

enum CardioExerciseCategoryGrouping {
    /// Display order for cardio library sections (matches `CardioActivityKind` cases).
    static let activityOrder: [CardioActivityKind] = CardioActivityKind.allCases

    /// Sections of cardio exercises grouped by activity kind, sorted by display name within each section.
    static func activitySections(
        exercises: [Exercise],
        displayName: (Exercise) -> String
    ) -> [(CardioActivityKind, [Exercise])] {
        let cardioOnly = exercises.filter { $0.modality == .cardio || $0.modality == .hybrid }
        let grouped = Dictionary(grouping: cardioOnly) { ex in
            ex.cardioMetadata?.activityKind ?? .generic
        }
        return activityOrder.compactMap { kind in
            let list = (grouped[kind] ?? []).sorted {
                displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending
            }
            return list.isEmpty ? nil : (kind, list)
        }
    }
}
