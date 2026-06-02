//
//  ExerciseFormGuideMapper.swift
//  FitLog
//
//  Maps FitLog exercise names to MuscleWiki search queries / IDs.
//

import Foundation

@MainActor
enum ExerciseFormGuideMapper {
    private static let bundledMappings: [String: ExerciseFormGuideMappingEntry] = {
        guard let url = Bundle.main.url(forResource: "ExerciseFormGuideMapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ExerciseFormGuideMappingFile.self, from: data)
        else {
            return [:]
        }
        return file.mappings
    }()

    private static var resolvedCache: [String: ExerciseFormGuideMappingEntry] = [:]

    static func mapping(for exercise: Exercise, muscleWikiOverrideId: Int? = nil) -> ExerciseFormGuideMappingEntry? {
        let canonical = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return nil }

        if let overrideId = muscleWikiOverrideId {
            let entry = ExerciseFormGuideMappingEntry(searchQuery: canonical, muscleWikiId: overrideId)
            storeCache(canonical, entry)
            return entry
        }

        if let cached = resolvedCache[canonical] {
            return cached
        }

        if let exact = bundledMappings[canonical] {
            storeCache(canonical, exact)
            return exact
        }

        let lowered = canonical.lowercased()
        if let match = bundledMappings.first(where: { $0.key.lowercased() == lowered })?.value {
            storeCache(canonical, match)
            return match
        }

        if let fuzzy = fuzzyBundledMatch(for: canonical) {
            storeCache(canonical, fuzzy)
            return fuzzy
        }

        let fallback = ExerciseFormGuideMappingEntry(searchQuery: canonical, muscleWikiId: nil)
        storeCache(canonical, fallback)
        return fallback
    }

    static func searchQuery(for exercise: Exercise, muscleWikiOverrideId: Int? = nil) -> String {
        mapping(for: exercise, muscleWikiOverrideId: muscleWikiOverrideId)?.searchQuery ?? exercise.name
    }

    /// Exposed for unit tests to verify the bundled JSON is present in the app bundle.
    static var bundledMappingCount: Int {
        bundledMappings.count
    }

    private static func storeCache(_ key: String, _ value: ExerciseFormGuideMappingEntry) {
        resolvedCache[key] = value
    }

    private static func fuzzyBundledMatch(for name: String) -> ExerciseFormGuideMappingEntry? {
        let normalized = normalize(name)
        var best: (entry: ExerciseFormGuideMappingEntry, score: Int)?
        for (key, entry) in bundledMappings {
            let score = fuzzyScore(normalized, normalize(key))
            guard score > 0 else { continue }
            if best == nil || score > best!.score {
                best = (entry, score)
            }
        }
        return best?.entry
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Simple token overlap score for custom / renamed exercises.
    private static func fuzzyScore(_ a: String, _ b: String) -> Int {
        let tokensA = Set(a.split(separator: " ").map(String.init))
        let tokensB = Set(b.split(separator: " ").map(String.init))
        guard !tokensA.isEmpty, !tokensB.isEmpty else { return 0 }
        let overlap = tokensA.intersection(tokensB).count
        let required = min(tokensA.count, tokensB.count)
        return overlap >= max(2, required - 1) ? overlap : 0
    }
}
