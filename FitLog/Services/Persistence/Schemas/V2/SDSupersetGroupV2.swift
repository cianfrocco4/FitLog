//
//  SDSupersetGroupV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSupersetGroupV2 {
    var groupId: UUID = UUID()
    /// "superset", "circuit", or "cluster"
    var kindRaw: String = "superset"
    var restAfterGroupSeconds: Int = 120

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutExerciseRowV2.supersetGroup)
    var memberRows: [SDWorkoutExerciseRowV2] = []

    init() {}

    init(groupId: UUID, kindRaw: String, restAfterGroupSeconds: Int) {
        self.groupId = groupId
        self.kindRaw = kindRaw
        self.restAfterGroupSeconds = restAfterGroupSeconds
    }
}
