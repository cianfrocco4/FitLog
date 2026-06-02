//
//  PersonalRecordStore.swift
//  FitLog
//
//  Incrementally maintained PR table backed by SDPersonalRecordV2.
//  Replaces the full-history scan in PersonalRecordDetector with O(1) per-exercise lookups.
//

import Foundation
import SwiftData

final class PersonalRecordStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Query

    func loadAllForBackup() -> [BackupPersonalRecord] {
        let descriptor = FetchDescriptor<SDPersonalRecordV2>()
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return MigrationSnapshotExtras.personalRecords(from: rows)
    }

    /// Replaces all PR rows with records from an imported backup snapshot.
    func replaceAllFromBackup(_ records: [BackupPersonalRecord]) {
        do {
            try modelContext.delete(model: SDPersonalRecordV2.self)
            MigrationSnapshotExtras.insertPersonalRecords(records, into: modelContext)
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Replace personal records failed: \(error.localizedDescription)")
            #endif
        }
    }

    func currentBests(forExerciseId id: UUID) -> [SDPersonalRecordV2] {
        let descriptor = FetchDescriptor<SDPersonalRecordV2>(
            predicate: #Predicate { $0.exerciseId == id }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func bestValues(forExerciseId id: UUID) -> (maxWeight: Double?, est1RM: Double?, maxVolume: Double?) {
        let rows = currentBests(forExerciseId: id)
        return (
            rows.first(where: { $0.kindRaw == PRKind.maxWeight.rawValue })?.value,
            rows.first(where: { $0.kindRaw == PRKind.estimatedOneRM.rawValue })?.value,
            rows.first(where: { $0.kindRaw == PRKind.maxVolume.rawValue })?.value
        )
    }

    // MARK: - Incremental update

    /// Compare `set` against stored best rows and update any rows that are beaten.
    /// Returns `[PersonalRecordEvent]` for each kind that was surpassed (empty if no PR).
    @discardableResult
    func updateIfPR(
        set: LoggedSet,
        exerciseId: UUID,
        exerciseName: String,
        sessionId: UUID
    ) -> [PersonalRecordEvent] {
        if set.countsTowardCardioTotals {
            return updateCardioIfPR(
                set: set,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                sessionId: sessionId
            )
        }
        guard set.countsTowardLoadPRMetrics else { return [] }

        let existing = currentBests(forExerciseId: exerciseId)
        var events: [PersonalRecordEvent] = []

        // — Max weight
        let newWeight = set.weight
        if let row = existing.first(where: { $0.kindRaw == PRKind.maxWeight.rawValue }) {
            if newWeight > row.value + 0.0001 {
                let prev = row.value
                row.value = newWeight; row.setId = set.id; row.sessionId = sessionId; row.achievedAt = set.timestamp
                events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                                  kind: .maxWeight, newValue: newWeight, previousValue: prev,
                                                  timestamp: set.timestamp))
            }
        } else {
            modelContext.insert(SDPersonalRecordV2(prId: UUID(), exerciseId: exerciseId,
                                                   kindRaw: PRKind.maxWeight.rawValue,
                                                   value: newWeight, setId: set.id,
                                                   sessionId: sessionId, achievedAt: set.timestamp))
            events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                              kind: .maxWeight, newValue: newWeight, previousValue: nil,
                                              timestamp: set.timestamp))
        }

        // — Estimated 1RM (Epley)
        let new1RM = PersonalRecordDetector.epley(weight: set.weight, reps: set.reps)
        if let row = existing.first(where: { $0.kindRaw == PRKind.estimatedOneRM.rawValue }) {
            if new1RM > row.value + 0.0001 {
                let prev = row.value
                row.value = new1RM; row.setId = set.id; row.sessionId = sessionId; row.achievedAt = set.timestamp
                events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                                  kind: .estimatedOneRM, newValue: new1RM, previousValue: prev,
                                                  timestamp: set.timestamp))
            }
        } else {
            modelContext.insert(SDPersonalRecordV2(prId: UUID(), exerciseId: exerciseId,
                                                   kindRaw: PRKind.estimatedOneRM.rawValue,
                                                   value: new1RM, setId: set.id,
                                                   sessionId: sessionId, achievedAt: set.timestamp))
            events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                              kind: .estimatedOneRM, newValue: new1RM, previousValue: nil,
                                              timestamp: set.timestamp))
        }

        // — Max set-volume (weight × reps, including drops)
        let newVolume = set.totalVolumeLoad
        if let row = existing.first(where: { $0.kindRaw == PRKind.maxVolume.rawValue }) {
            if newVolume > row.value + 0.0001 {
                let prev = row.value
                row.value = newVolume; row.setId = set.id; row.sessionId = sessionId; row.achievedAt = set.timestamp
                events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                                  kind: .maxVolumeSet, newValue: newVolume, previousValue: prev,
                                                  timestamp: set.timestamp))
            }
        } else {
            modelContext.insert(SDPersonalRecordV2(prId: UUID(), exerciseId: exerciseId,
                                                   kindRaw: PRKind.maxVolume.rawValue,
                                                   value: newVolume, setId: set.id,
                                                   sessionId: sessionId, achievedAt: set.timestamp))
            events.append(PersonalRecordEvent(exerciseId: exerciseId, exerciseName: exerciseName,
                                              kind: .maxVolumeSet, newValue: newVolume, previousValue: nil,
                                              timestamp: set.timestamp))
        }

        try? modelContext.save()
        return events
    }

    @discardableResult
    private func updateCardioIfPR(
        set: LoggedSet,
        exerciseId: UUID,
        exerciseName: String,
        sessionId: UUID
    ) -> [PersonalRecordEvent] {
        guard set.countsTowardCardioTotals, let metrics = set.cardioMetrics else { return [] }
        let existing = currentBests(forExerciseId: exerciseId)
        var events: [PersonalRecordEvent] = []

        func upsert(kind: PRKind, newValue: Double, better: (Double, Double) -> Bool) {
            if let row = existing.first(where: { $0.kindRaw == kind.rawValue }) {
                if better(newValue, row.value) {
                    let prev = row.value
                    row.value = newValue
                    row.setId = set.id
                    row.sessionId = sessionId
                    row.achievedAt = set.timestamp
                    events.append(
                        PersonalRecordEvent(
                            exerciseId: exerciseId,
                            exerciseName: exerciseName,
                            kind: kind.eventKind,
                            newValue: newValue,
                            previousValue: prev,
                            timestamp: set.timestamp
                        )
                    )
                }
            } else {
                modelContext.insert(
                    SDPersonalRecordV2(
                        prId: UUID(),
                        exerciseId: exerciseId,
                        kindRaw: kind.rawValue,
                        value: newValue,
                        setId: set.id,
                        sessionId: sessionId,
                        achievedAt: set.timestamp
                    )
                )
                events.append(
                    PersonalRecordEvent(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        kind: kind.eventKind,
                        newValue: newValue,
                        previousValue: nil,
                        timestamp: set.timestamp
                    )
                )
            }
        }

        if let dist = metrics.distanceM, dist > 0 {
            upsert(kind: .maxDistance, newValue: dist) { $0 > $1 + 0.0001 }
        }
        if let sec = metrics.durationSec, sec > 0 {
            upsert(kind: .longestDuration, newValue: Double(sec)) { $0 > $1 + 0.0001 }
        }
        if let pace = metrics.resolvedPaceSecPerKm, pace > 0 {
            upsert(kind: .bestPace, newValue: Double(pace)) { $0 < $1 - 0.0001 || $1 == 0 }
        }
        if let cal = metrics.calories, cal > 0 {
            upsert(kind: .maxCalories, newValue: cal) { $0 > $1 + 0.0001 }
        }

        if !events.isEmpty { try? modelContext.save() }
        return events
    }

    // MARK: - Reconciliation

    /// Recomputes stored PR rows for one exercise from the provided set history (e.g. after delete/edit).
    func reconcileBests(
        forExerciseId exerciseId: UUID,
        fromSets sets: [(set: LoggedSet, sessionId: UUID)],
        exerciseName: String
    ) {
        let existing = currentBests(forExerciseId: exerciseId)
        for row in existing {
            modelContext.delete(row)
        }

        let strengthEntries = sets.filter { $0.set.countsTowardLoadPRMetrics }
        if let bestWeightEntry = strengthEntries.max(by: { $0.set.weight < $1.set.weight }) {
            insertPRRow(
                exerciseId: exerciseId,
                kind: .maxWeight,
                value: bestWeightEntry.set.weight,
                set: bestWeightEntry.set,
                sessionId: bestWeightEntry.sessionId
            )
        }
        if let best1RMEntry = strengthEntries.max(by: {
            PersonalRecordDetector.epley(weight: $0.set.weight, reps: $0.set.reps)
                < PersonalRecordDetector.epley(weight: $1.set.weight, reps: $1.set.reps)
        }) {
            insertPRRow(
                exerciseId: exerciseId,
                kind: .estimatedOneRM,
                value: PersonalRecordDetector.epley(weight: best1RMEntry.set.weight, reps: best1RMEntry.set.reps),
                set: best1RMEntry.set,
                sessionId: best1RMEntry.sessionId
            )
        }
        if let bestVolumeEntry = strengthEntries.max(by: { $0.set.totalVolumeLoad < $1.set.totalVolumeLoad }) {
            insertPRRow(
                exerciseId: exerciseId,
                kind: .maxVolume,
                value: bestVolumeEntry.set.totalVolumeLoad,
                set: bestVolumeEntry.set,
                sessionId: bestVolumeEntry.sessionId
            )
        }

        let cardioEntries = sets.filter { $0.set.countsTowardCardioTotals }
        if let bestDistance = cardioEntries.compactMap({ entry -> (LoggedSet, UUID, Double)? in
            guard let dist = entry.set.cardioMetrics?.distanceM, dist > 0 else { return nil }
            return (entry.set, entry.sessionId, dist)
        }).max(by: { $0.2 < $1.2 }) {
            insertPRRow(exerciseId: exerciseId, kind: .maxDistance, value: bestDistance.2, set: bestDistance.0, sessionId: bestDistance.1)
        }
        if let bestDuration = cardioEntries.compactMap({ entry -> (LoggedSet, UUID, Double)? in
            guard let sec = entry.set.cardioMetrics?.durationSec, sec > 0 else { return nil }
            return (entry.set, entry.sessionId, Double(sec))
        }).max(by: { $0.2 < $1.2 }) {
            insertPRRow(exerciseId: exerciseId, kind: .longestDuration, value: bestDuration.2, set: bestDuration.0, sessionId: bestDuration.1)
        }
        if let bestPace = cardioEntries.compactMap({ entry -> (LoggedSet, UUID, Double)? in
            guard let pace = entry.set.cardioMetrics?.resolvedPaceSecPerKm, pace > 0 else { return nil }
            return (entry.set, entry.sessionId, Double(pace))
        }).min(by: { $0.2 < $1.2 }) {
            insertPRRow(exerciseId: exerciseId, kind: .bestPace, value: bestPace.2, set: bestPace.0, sessionId: bestPace.1)
        }
        if let bestCalories = cardioEntries.compactMap({ entry -> (LoggedSet, UUID, Double)? in
            guard let cal = entry.set.cardioMetrics?.calories, cal > 0 else { return nil }
            return (entry.set, entry.sessionId, cal)
        }).max(by: { $0.2 < $1.2 }) {
            insertPRRow(exerciseId: exerciseId, kind: .maxCalories, value: bestCalories.2, set: bestCalories.0, sessionId: bestCalories.1)
        }

        try? modelContext.save()
    }

    private func insertPRRow(
        exerciseId: UUID,
        kind: PRKind,
        value: Double,
        set: LoggedSet,
        sessionId: UUID
    ) {
        modelContext.insert(
            SDPersonalRecordV2(
                prId: UUID(),
                exerciseId: exerciseId,
                kindRaw: kind.rawValue,
                value: value,
                setId: set.id,
                sessionId: sessionId,
                achievedAt: set.timestamp
            )
        )
    }
}

// MARK: - PRKind ↔ PersonalRecordEvent.Kind bridge
extension PRKind {
    var eventKind: PersonalRecordEvent.Kind {
        switch self {
        case .maxWeight:    return .maxWeight
        case .estimatedOneRM: return .estimatedOneRM
        case .maxVolume:    return .maxVolumeSet
        case .maxDistance:  return .maxDistance
        case .bestPace:     return .bestPace
        case .longestDuration: return .longestDuration
        case .maxCalories:  return .maxCalories
        }
    }
}

extension PersonalRecordEvent.Kind {
    var prKind: PRKind {
        switch self {
        case .maxWeight:    return .maxWeight
        case .estimatedOneRM: return .estimatedOneRM
        case .maxVolumeSet:  return .maxVolume
        case .maxDistance:  return .maxDistance
        case .bestPace:     return .bestPace
        case .longestDuration: return .longestDuration
        case .maxCalories:  return .maxCalories
        }
    }
}
