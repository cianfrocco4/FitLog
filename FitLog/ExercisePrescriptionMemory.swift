//
//  ExercisePrescriptionMemory.swift
//  FitLog
//

import Foundation

/// Remembers last-used sets × reps per exercise for quick-add defaults.
enum ExercisePrescriptionMemory {
    private static let key = "exercisePrescriptionMemory.v1"

    private struct Entry: Codable, Equatable {
        var sets: Int
        var reps: String
    }

    private static func loadMap() -> [UUID: Entry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        var out: [UUID: Entry] = [:]
        for (k, v) in decoded {
            if let id = UUID(uuidString: k) { out[id] = v }
        }
        return out
    }

    private static func saveMap(_ map: [UUID: Entry]) {
        let encodable = Dictionary(uniqueKeysWithValues: map.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func rememberedSetsAndReps(for exerciseId: UUID) -> (sets: Int, reps: String)? {
        guard let e = loadMap()[exerciseId] else { return nil }
        let sets = min(10, max(1, e.sets))
        let reps = e.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reps.isEmpty else { return nil }
        return (sets, reps)
    }

    static func remember(exerciseId: UUID, sets: Int, reps: String) {
        var map = loadMap()
        let s = min(10, max(1, sets))
        let r = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        map[exerciseId] = Entry(sets: s, reps: r)
        saveMap(map)
    }
}
