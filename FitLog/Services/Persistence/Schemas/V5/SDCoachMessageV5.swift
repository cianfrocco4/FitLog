//
//  SDCoachMessageV5.swift
//  FitLog
//
//  Persisted Coach tab message (V5 schema).
//

import Foundation
import SwiftData

@Model
final class SDCoachMessageV5 {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var roleRaw: String = CoachMessageRole.user.rawValue
    var text: String = ""
    var statusRaw: String = CoachMessageStatus.sent.rawValue
    var feedbackRaw: String?

    /// Plain inverse — no @Relationship on this side (aggregate owns the edge).
    var conversation: SDCoachConversationV5?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        roleRaw: String = CoachMessageRole.user.rawValue,
        text: String = "",
        statusRaw: String = CoachMessageStatus.sent.rawValue,
        feedbackRaw: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.roleRaw = roleRaw
        self.text = text
        self.statusRaw = statusRaw
        self.feedbackRaw = feedbackRaw
    }
}
