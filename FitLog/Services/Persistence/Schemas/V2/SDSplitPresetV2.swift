//
//  SDSplitPresetV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDSplitPresetV2 {
    var presetId: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var notes: String = ""
    var sessionsPerWeek: Int = 3
    var preferredWeekdaysData: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \SDSplitPresetDayV2.preset)
    var days: [SDSplitPresetDayV2] = []

    init() {}

    init(presetId: UUID, name: String, createdAt: Date, notes: String, sessionsPerWeek: Int) {
        self.presetId = presetId
        self.name = name
        self.createdAt = createdAt
        self.notes = notes
        self.sessionsPerWeek = sessionsPerWeek
    }
}
