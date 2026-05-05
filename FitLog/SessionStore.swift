//
//  SessionStore.swift
//  FitLog
//
//  Session persistence. Reads/writes SDWorkoutSessionV2 rows.
//

import Foundation
import SwiftData

final class SessionStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load / save

    func loadSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<SDWorkoutSessionV2>(sortBy: [SortDescriptor(\.startTime)])
        guard let rows = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData V2] Loaded \(rows.count) sessions")
        #endif
        return rows.compactMap { $0.toDomain() }
    }

    func appendSession(_ session: WorkoutSession) {
        modelContext.insert(SDWorkoutSessionV2.from(session))
        try? modelContext.save()
    }

    @discardableResult
    func saveSessions(_ sessions: [WorkoutSession]) -> Bool {
        do {
            try modelContext.delete(model: SDWorkoutSessionV2.self)
            for s in sessions {
                modelContext.insert(SDWorkoutSessionV2.from(s))
            }
            try modelContext.save()
            return true
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save sessions failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Active session

    /// Returns the first session with no endTime (in-progress workout).
    func loadActiveSession() -> WorkoutSession? {
        var descriptor = FetchDescriptor<SDWorkoutSessionV2>(
            predicate: #Predicate { $0.endTime == nil }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.toDomain()
    }

    func upsertActiveSession(_ session: WorkoutSession) {
        // Remove any existing active row first
        clearActiveSession()
        let row = SDWorkoutSessionV2.from(session)
        modelContext.insert(row)
        try? modelContext.save()
    }

    func clearActiveSession() {
        let descriptor = FetchDescriptor<SDWorkoutSessionV2>(
            predicate: #Predicate { $0.endTime == nil }
        )
        if let rows = try? modelContext.fetch(descriptor) {
            for row in rows { modelContext.delete(row) }
        }
        try? modelContext.save()
    }
}
