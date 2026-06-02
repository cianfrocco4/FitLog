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
        let completedRows = rows.filter { $0.endTime != nil }
        #if DEBUG
        print("[SwiftData V2] Loaded \(completedRows.count) completed sessions")
        #endif
        return completedRows.compactMap { $0.toDomain() }
    }

    func appendSession(_ session: WorkoutSession) {
        upsertSession(session)
    }

    @discardableResult
    func upsertSession(_ session: WorkoutSession) -> Bool {
        let sessionId = session.id
        let descriptor = FetchDescriptor<SDWorkoutSessionV2>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for row in existing {
                modelContext.delete(row)
            }
        }
        modelContext.insert(SDWorkoutSessionV2.from(session))
        do {
            try modelContext.save()
            return true
        } catch {
            #if DEBUG
            print("[SwiftData V2] Upsert session failed: \(error.localizedDescription)")
            #endif
            return false
        }
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

    @discardableResult
    func upsertActiveSession(_ session: WorkoutSession) -> Bool {
        clearActiveSession()
        let row = SDWorkoutSessionV2.from(session)
        modelContext.insert(row)
        do {
            try modelContext.save()
            return true
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save active session failed: \(error.localizedDescription)")
            #endif
            return false
        }
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
