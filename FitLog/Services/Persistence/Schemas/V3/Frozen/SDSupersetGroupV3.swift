//
//  SDSupersetGroupV3.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSupersetGroupV3 {
    var groupId: UUID = UUID()
    var kindRaw: String = "superset"
    var restAfterGroupSeconds: Int = 120

    @Relationship(deleteRule: .nullify, inverse: \SDWorkoutExerciseRowV3.supersetGroup)
    var memberRows: [SDWorkoutExerciseRowV3] = []

    init() {}

    init(groupId: UUID, kindRaw: String, restAfterGroupSeconds: Int) {
        self.groupId = groupId
        self.kindRaw = kindRaw
        self.restAfterGroupSeconds = restAfterGroupSeconds
    }
}
