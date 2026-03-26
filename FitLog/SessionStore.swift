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

    // MARK: - Analytics

    func completedSessionCount(inWeekContaining referenceDate: Date, calendar: Calendar) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        let start = interval.start
        let end = interval.end
        var descriptor = FetchDescriptor<SDWorkoutSession>(
            predicate: #Predicate<SDWorkoutSession> { $0.endTime != nil && $0.endTime! >= start && $0.endTime! < end }
        )
        descriptor.fetchLimit = 100
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func hasCompletedSessionEnding(on dayStart: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: dayStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        var descriptor = FetchDescriptor<SDWorkoutSession>(
            predicate: #Predicate<SDWorkoutSession> { $0.endTime != nil && $0.endTime! >= start && $0.endTime! < dayEnd }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
