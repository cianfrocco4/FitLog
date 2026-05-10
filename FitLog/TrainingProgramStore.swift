//
//  TrainingProgramStore.swift
//  FitLog
//
//  Training program state persistence. Reads/writes SDTrainingProgramV2.
//

import Foundation
import SwiftData

final class TrainingProgramStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load / save

    func loadProgram() -> TrainingProgramState? {
        let descriptor = FetchDescriptor<SDTrainingProgramV2>()
        guard let rows = try? modelContext.fetch(descriptor),
              let first = rows.first else { return nil }
        return first.toDomain()
    }

    func saveProgram(_ program: TrainingProgramState) {
        do {
            try modelContext.delete(model: SDTrainingProgramV2.self)
            modelContext.insert(SDTrainingProgramV2.from(program))
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save training program failed: \(error.localizedDescription)")
            #endif
        }
    }
}
