//
//  SetEntryDraftStore.swift
//  FitLog
//
//  Encapsulates per-exercise-log inline draft state for the workout pull-up sheet
//  (replaces parallel UUID-keyed @State dictionaries on the view).
//

import Foundation
import Observation

/// Per-session inline quick-log drafts keyed by `ExerciseLog.id`.
@MainActor
@Observable
final class SetEntryDraftStore {
    var weightByLogId: [UUID: Double] = [:]
    var repsByLogId: [UUID: Int] = [:]
    var weightTextByLogId: [UUID: String] = [:]
    var repsTextByLogId: [UUID: String] = [:]
    var initializedLogIds: Set<UUID> = []
    var bodyweightModeLogIds: Set<UUID> = []
    var bodyweightAddedByLogId: [UUID: Double] = [:]
    var bodyweightAssistedByLogId: [UUID: Double] = [:]
    var bodyweightAddedTextByLogId: [UUID: String] = [:]
    var bodyweightAssistedTextByLogId: [UUID: String] = [:]
    var rpeByLogId: [UUID: Double] = [:]
    var rpeExpandedLogIds: Set<UUID> = []
    /// Inline quick-log set type (defaults to working when absent).
    var setTypeByLogId: [UUID: ExerciseSetType] = [:]
    /// Setup chosen for the next set (grip, seat, attachment). Sticky across logs on purpose:
    /// the machine keeps its setting until the user changes it.
    var configurationByLogId: [UUID: [String: String]] = [:]

    func clear(logId: UUID) {
        weightByLogId.removeValue(forKey: logId)
        repsByLogId.removeValue(forKey: logId)
        weightTextByLogId.removeValue(forKey: logId)
        repsTextByLogId.removeValue(forKey: logId)
        initializedLogIds.remove(logId)
        rpeByLogId.removeValue(forKey: logId)
        rpeExpandedLogIds.remove(logId)
        bodyweightModeLogIds.remove(logId)
        bodyweightAddedByLogId.removeValue(forKey: logId)
        bodyweightAssistedByLogId.removeValue(forKey: logId)
        bodyweightAddedTextByLogId.removeValue(forKey: logId)
        bodyweightAssistedTextByLogId.removeValue(forKey: logId)
        setTypeByLogId.removeValue(forKey: logId)
        configurationByLogId.removeValue(forKey: logId)
    }
}
