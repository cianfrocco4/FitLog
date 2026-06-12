//
//  SDCoachConversationV5.swift
//  FitLog
//
//  Persisted Coach tab conversation thread (V5 schema).
//

import Foundation
import SwiftData

@Model
final class SDCoachConversationV5 {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = "New chat"

    @Relationship(deleteRule: .cascade, inverse: \SDCoachMessageV5.conversation)
    var messages: [SDCoachMessageV5] = []

    init(id: UUID = UUID(), createdAt: Date = Date(), updatedAt: Date = Date(), title: String = "New chat") {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
    }
}
