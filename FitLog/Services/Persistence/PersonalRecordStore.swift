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
