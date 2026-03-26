//
//  TrainingProgramStore.swift
//  FitLog
//
//  Training program state and schedule overrides, extracted from DataManager.
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
        let descriptor = FetchDescriptor<SDTrainingProgram>()
        guard let sdPrograms = try? modelContext.fetch(descriptor),
              let first = sdPrograms.first else { return nil }
        return first.toStruct()
    }

    func saveProgram(_ program: TrainingProgramState) {
        do {
            try modelContext.delete(model: SDTrainingProgram.self)
            modelContext.insert(SDTrainingProgram.from(program))
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save training program failed: \(error.localizedDescription)")
            #endif
        }
    }
}
