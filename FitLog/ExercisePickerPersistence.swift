//
//  ExercisePickerPersistence.swift
//  FitLog
//

import Foundation

enum ExercisePickerPersistence {
    static let favoritesKey = "exercisePickerFavorites"
    static let recentKey = "exercisePickerRecent"
    static let recentMaxCount = 15

    static func loadFavorites() -> Set<UUID> {
        guard let raw = UserDefaults.standard.stringArray(forKey: favoritesKey) else { return [] }
        return Set(raw.compactMap { UUID(uuidString: $0) })
    }

    static func saveFavorites(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: favoritesKey)
    }

    static func loadRecent() -> [UUID] {
        (UserDefaults.standard.stringArray(forKey: recentKey) ?? []).compactMap { UUID(uuidString: $0) }
    }

    static func recordRecent(exerciseId: UUID) {
        var ids = loadRecent()
        ids.removeAll { $0 == exerciseId }
        ids.insert(exerciseId, at: 0)
        ids = Array(ids.prefix(recentMaxCount))
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: recentKey)
    }
}
