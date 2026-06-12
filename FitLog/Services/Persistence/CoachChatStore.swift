//
//  CoachChatStore.swift
//  FitLog
//
//  CRUD for persisted Coach tab conversations (SwiftData V5).
//

import Foundation
import SwiftData

enum CoachChatStoreLimits {
    static let maxConversationMessages = 40
}

final class CoachChatStore {
    private let modelContext: ModelContext
    private let failureReporter: PersistenceFailureReporter

    init(modelContext: ModelContext, failureReporter: PersistenceFailureReporter) {
        self.modelContext = modelContext
        self.failureReporter = failureReporter
    }

    // MARK: - Conversations

    func loadConversations() -> [CoachConversationSummary] {
        let descriptor = FetchDescriptor<SDCoachConversationV5>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let rows = try? modelContext.fetch(descriptor) else { return [] }
        return rows
            .filter { !$0.messages.isEmpty }
            .map { $0.toSummary() }
    }

    func createConversation(title: String = "New chat") -> UUID {
        let row = SDCoachConversationV5(title: title)
        modelContext.insert(row)
        _ = save()
        return row.id
    }

    func renameConversation(id: UUID, title: String) {
        guard let row = fetchConversation(id: id) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        row.title = trimmed.isEmpty ? "New chat" : String(trimmed.prefix(80))
        row.updatedAt = Date()
        _ = save()
    }

    func deleteConversation(id: UUID) {
        guard let row = fetchConversation(id: id) else { return }
        modelContext.delete(row)
        _ = save()
    }

    /// Removes stored conversations with zero messages (e.g. abandoned "New chat" rows).
    func pruneEmptyConversations() {
        let descriptor = FetchDescriptor<SDCoachConversationV5>()
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        for row in rows where row.messages.isEmpty {
            modelContext.delete(row)
        }
        _ = save()
    }

    // MARK: - Messages

    func loadMessages(
        conversationID: UUID,
        limit: Int = CoachChatStoreLimits.maxConversationMessages
    ) -> [CoachChatMessage] {
        guard let row = fetchConversation(id: conversationID) else { return [] }
        let sorted = row.messages.sorted { $0.createdAt < $1.createdAt }
        let tail = limit > 0 ? Array(sorted.suffix(limit)) : sorted
        return tail.map { $0.toDomain() }
    }

    @discardableResult
    func appendMessage(_ message: CoachChatMessage, conversationID: UUID) -> Bool {
        guard let row = fetchConversation(id: conversationID) else { return false }
        let sd = SDCoachMessageV5.from(message, conversation: row)
        row.messages.append(sd)
        row.updatedAt = Date()
        autoTitleIfNeeded(conversation: row, from: message)
        trimMessagesIfNeeded(conversation: row)
        return save()
    }

    @discardableResult
    func updateMessage(_ message: CoachChatMessage, conversationID: UUID) -> Bool {
        guard let row = fetchConversation(id: conversationID),
              let sd = row.messages.first(where: { $0.id == message.id }) else { return false }
        sd.apply(message)
        row.updatedAt = Date()
        return save()
    }

    @discardableResult
    func deleteMessage(id: UUID, conversationID: UUID) -> Bool {
        guard let row = fetchConversation(id: conversationID),
              let sd = row.messages.first(where: { $0.id == id }) else { return false }
        row.messages.removeAll { $0.id == id }
        modelContext.delete(sd)
        row.updatedAt = Date()
        return save()
    }

    func setFeedback(messageID: UUID, conversationID: UUID, feedback: CoachMessageFeedback?) -> Bool {
        guard let row = fetchConversation(id: conversationID),
              let sd = row.messages.first(where: { $0.id == messageID }) else { return false }
        sd.feedbackRaw = feedback?.rawValue
        return save()
    }

    func clearConversationMessages(conversationID: UUID) {
        guard let row = fetchConversation(id: conversationID) else { return }
        for msg in row.messages {
            modelContext.delete(msg)
        }
        row.messages.removeAll()
        row.updatedAt = Date()
        _ = save()
    }

    // MARK: - Private

    private func fetchConversation(id: UUID) -> SDCoachConversationV5? {
        var descriptor = FetchDescriptor<SDCoachConversationV5>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func autoTitleIfNeeded(conversation: SDCoachConversationV5, from message: CoachChatMessage) {
        guard conversation.title == "New chat", message.role == .user else { return }
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let words = trimmed.split(separator: " ").prefix(6).joined(separator: " ")
        conversation.title = String(words.prefix(80))
    }

    private func trimMessagesIfNeeded(conversation: SDCoachConversationV5) {
        let maxCount = CoachChatStoreLimits.maxConversationMessages
        guard conversation.messages.count > maxCount else { return }
        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        let overflow = sorted.prefix(sorted.count - maxCount)
        for msg in overflow {
            modelContext.delete(msg)
            conversation.messages.removeAll { $0.id == msg.id }
        }
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            let message = "Could not save coach chat. Your messages may not persist after you quit the app."
            Task { @MainActor in
                failureReporter.report(message)
            }
            return false
        }
    }
}
