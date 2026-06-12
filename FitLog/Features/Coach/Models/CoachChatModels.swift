//
//  CoachChatModels.swift
//  FitLog
//
//  Domain types for the free-form Coach chat tab.
//

import Foundation

enum CoachMessageRole: String, Codable, Sendable {
    case user
    case assistant
}

enum CoachMessageStatus: String, Codable, Sendable {
    case sent
    case streaming
    case failed
}

enum CoachMessageFeedback: String, Codable, Sendable {
    case up
    case down
}

struct CoachConversationSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messageCount: Int
    var previewText: String?
}

struct CoachChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: CoachMessageRole
    var text: String
    let created: Date
    var status: CoachMessageStatus
    var feedback: CoachMessageFeedback?
    var actions: [CoachChatAction]

    var isUser: Bool { role == .user }

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        created: Date = Date(),
        status: CoachMessageStatus = .sent,
        feedback: CoachMessageFeedback? = nil,
        actions: [CoachChatAction] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.created = created
        self.status = status
        self.feedback = feedback
        self.actions = actions
    }

    init(isUser: Bool, text: String, created: Date = Date()) {
        self.init(role: isUser ? .user : .assistant, text: text, created: created)
    }
}

// MARK: - Actionable suggestions

enum CoachChatActionKind: String, Codable, Sendable {
    case openProgramBuilder
    case openPlanTab
    case openHomeTab
}

struct CoachChatAction: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let kind: CoachChatActionKind
    let title: String
    let detail: String?
    let prefill: String?
    let isApplied: Bool

    init(
        id: UUID = UUID(),
        kind: CoachChatActionKind,
        title: String,
        detail: String? = nil,
        prefill: String? = nil,
        isApplied: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.prefill = prefill
        self.isApplied = isApplied
    }
}

struct CoachChatStructuredResponse: Equatable, Sendable {
    let reply: String
    let actions: [CoachChatAction]
}

// MARK: - Context transparency

struct CoachContextSummary: Equatable, Sendable {
    var todayPlan: String
    var programSummary: String
    var workoutCount: Int
    var recentSessionCount: Int
    var sessionsThisWeek: Int
    var wasTruncated: Bool
}

// MARK: - SwiftData mapping

extension SDCoachConversationV5 {
    func toSummary() -> CoachConversationSummary {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        let preview = sorted.last(where: { $0.roleRaw == CoachMessageRole.assistant.rawValue })?.text
            ?? sorted.last?.text
        return CoachConversationSummary(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messageCount: messages.count,
            previewText: preview.map { String($0.prefix(120)) }
        )
    }
}

extension SDCoachMessageV5 {
    func toDomain() -> CoachChatMessage {
        let role = CoachMessageRole(rawValue: roleRaw) ?? .assistant
        let status = CoachMessageStatus(rawValue: statusRaw) ?? .sent
        let feedback = feedbackRaw.flatMap { CoachMessageFeedback(rawValue: $0) }
        return CoachChatMessage(
            id: id,
            role: role,
            text: text,
            created: createdAt,
            status: status,
            feedback: feedback
        )
    }

    static func from(_ message: CoachChatMessage, conversation: SDCoachConversationV5) -> SDCoachMessageV5 {
        let row = SDCoachMessageV5(
            id: message.id,
            createdAt: message.created,
            roleRaw: message.role.rawValue,
            text: message.text,
            statusRaw: message.status.rawValue,
            feedbackRaw: message.feedback?.rawValue
        )
        row.conversation = conversation
        return row
    }

    func apply(_ message: CoachChatMessage) {
        text = message.text
        statusRaw = message.status.rawValue
        feedbackRaw = message.feedback?.rawValue
    }
}
