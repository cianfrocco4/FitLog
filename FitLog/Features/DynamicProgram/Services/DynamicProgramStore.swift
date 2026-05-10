//
//  DynamicProgramStore.swift
//  FitLog
//
//  Loads and saves `SDDynamicProgramV2` (active dynamic program state).
//

import Foundation
import SwiftData

final class DynamicProgramStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadActiveState() -> DynamicProgramState? {
        let descriptor = FetchDescriptor<SDDynamicProgramV2>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let rows = try? modelContext.fetch(descriptor),
              let first = rows.first else { return nil }
        return first.toDomain()
    }

    func saveActiveState(_ state: DynamicProgramState) {
        do {
            let all = try modelContext.fetch(FetchDescriptor<SDDynamicProgramV2>())
            for row in all {
                modelContext.delete(row)
            }
            modelContext.insert(SDDynamicProgramV2.from(state))
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save dynamic program failed: \(error.localizedDescription)")
            #endif
        }
    }

    func clearActiveState() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<SDDynamicProgramV2>())
            for row in all { modelContext.delete(row) }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Clear dynamic program failed: \(error.localizedDescription)")
            #endif
        }
    }
}
