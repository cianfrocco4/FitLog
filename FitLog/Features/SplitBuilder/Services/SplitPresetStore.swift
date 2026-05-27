//
//  SplitPresetStore.swift
//  FitLog
//
//  Manages saved workout split presets (Task 19).
//  Users can save a split configuration (days + slots) for reuse later.
//

import Foundation
import SwiftData

final class SplitPresetStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load

    func loadPresets() -> [SDSplitPresetV2] {
        let descriptor = FetchDescriptor<SDSplitPresetV2>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func preset(byId id: UUID) -> SDSplitPresetV2? {
        let descriptor = FetchDescriptor<SDSplitPresetV2>(
            predicate: #Predicate { $0.presetId == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Save

    func savePreset(
        name: String,
        notes: String,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        days: [SplitBuilderEditableDay]
    ) -> SDSplitPresetV2 {
        let preset = SDSplitPresetV2(
            presetId: UUID(),
            name: name,
            createdAt: Date(),
            notes: notes,
            sessionsPerWeek: sessionsPerWeek
        )
        preset.preferredWeekdaysData = (try? JSONEncoder().encode(preferredWeekdays)) ?? Data()

        for (dayIndex, dayData) in days.enumerated() {
            let day = SDSplitPresetDayV2(orderIndex: dayIndex, dayName: dayData.name)
            day.preset = preset
            for (slotIndex, slotData) in dayData.slots.enumerated() {
                let slot = SDSplitPresetSlotV2(
                    orderIndex: slotIndex,
                    exerciseName: slotData.label,
                    recommendedSets: slotData.sets,
                    recommendedReps: slotData.reps
                )
                slot.day = day
                day.slots.append(slot)
                modelContext.insert(slot)
            }
            preset.days.append(day)
            modelContext.insert(day)
        }

        modelContext.insert(preset)
        try? modelContext.save()
        return preset
    }

    // MARK: - Delete

    func deletePreset(_ preset: SDSplitPresetV2) {
        modelContext.delete(preset)
        try? modelContext.save()
    }

    /// Replaces all saved presets with rows from an imported backup snapshot.
    func replaceAllFromBackup(_ presets: [BackupSplitPreset]) {
        do {
            try modelContext.delete(model: SDSplitPresetV2.self)
            MigrationSnapshotExtras.insertSplitPresets(presets, into: modelContext)
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Replace split presets failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Conversion helpers

    /// Convert a saved preset back to SplitBuilderEditableDay format for editing.
    func toDomain(_ preset: SDSplitPresetV2) -> (name: String, days: [SplitBuilderEditableDay], sessionsPerWeek: Int, preferredWeekdays: [Int]) {
        let preferredWeekdays = (try? JSONDecoder().decode([Int].self, from: preset.preferredWeekdaysData)) ?? []
        let days = preset.days.sorted { $0.orderIndex < $1.orderIndex }.map { day in
            let slots = day.slots.sorted { $0.orderIndex < $1.orderIndex }.map { slot in
                SplitBuilderEditableSlot(
                    id: UUID(),
                    label: slot.exerciseName,
                    targetMuscleNames: [],
                    sets: slot.recommendedSets,
                    reps: slot.recommendedReps,
                    suggestedExerciseName: slot.exerciseName,
                    suggestedExerciseOverrideId: nil
                )
            }
            return SplitBuilderEditableDay(id: UUID(), name: day.dayName, focus: "", slots: slots)
        }
        return (preset.name, days, preset.sessionsPerWeek, preferredWeekdays)
    }
}
