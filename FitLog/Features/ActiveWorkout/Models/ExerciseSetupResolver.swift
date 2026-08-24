//
//  ExerciseSetupResolver.swift
//  FitLog
//
//  Resolves the per-set setup (grip, seat, attachment) for an exercise.
//

import Foundation

/// One setup field the user can set for the next set. Empty `choices` means free-form text.
struct ExerciseSetupField: Identifiable, Equatable, Hashable {
    var id: String { name }
    let name: String
    let choices: [String]
}

/// Machine variants (T-Bar Row wide / medium / narrow) live as setup on one canonical exercise
/// rather than near-duplicate library rows, so history and PRs stay on a single movement.
enum ExerciseSetupResolver {
    /// Plan-defined field names first, then library options the plan did not mention.
    static func fields(
        planFields: [String],
        libraryOptions: [ExerciseConfigurationOption]
    ) -> [ExerciseSetupField] {
        var seen = Set<String>()
        var fields: [ExerciseSetupField] = []

        for name in planFields {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            let choices = libraryOptions
                .first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }?
                .choices ?? []
            fields.append(ExerciseSetupField(name: trimmed, choices: choices))
        }

        for option in libraryOptions {
            let trimmed = option.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            fields.append(ExerciseSetupField(name: trimmed, choices: option.choices))
        }

        return fields
    }

    /// Values for the next set, weakest source first: the plan's recommendation for this set
    /// index, then the last logged set (the machine keeps its setting), then an explicit choice.
    static func values(
        setIndex: Int,
        recommendedConfigBySet: [[String: String]],
        lastLoggedConfiguration: [String: String]?,
        draft: [String: String]
    ) -> [String: String] {
        var values: [String: String] = [:]
        if recommendedConfigBySet.indices.contains(setIndex) {
            values = recommendedConfigBySet[setIndex]
        }
        if let lastLoggedConfiguration, !lastLoggedConfiguration.isEmpty {
            values.merge(lastLoggedConfiguration) { _, logged in logged }
        }
        values.merge(draft) { _, chosen in chosen }
        return values.filter { !$0.value.isEmpty }
    }

    /// "Grip: Wide, Seat: 3" for the fields that have a value, in field order.
    static func summary(fields: [ExerciseSetupField], values: [String: String]) -> String {
        fields.compactMap { field in
            guard let value = values[field.name], !value.isEmpty else { return nil }
            return "\(field.name): \(value)"
        }
        .joined(separator: ", ")
    }
}
