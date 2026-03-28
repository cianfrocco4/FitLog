//
//  SessionStore.swift
//  FitLog
//
//  Session persistence and analytics, extracted from DataManager.
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
        let descriptor = FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startTime)])
        guard let sdSessions = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData] Loaded \(sdSessions.count) sessions")
        #endif
        return sdSessions.compactMap { $0.toStruct() }
    }

    func appendSession(_ session: WorkoutSession) {
        modelContext.insert(SDWorkoutSession.from(session))
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Append session failed: \(error.localizedDescription)")
            #endif
        }
    }

    func saveSessions(_ sessions: [WorkoutSession]) {
        do {
            try modelContext.delete(model: SDWorkoutSession.self)
            for s in sessions {
                modelContext.insert(SDWorkoutSession.from(s))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save sessions failed: \(error.localizedDescription)")
            #endif
        }
    }
}
