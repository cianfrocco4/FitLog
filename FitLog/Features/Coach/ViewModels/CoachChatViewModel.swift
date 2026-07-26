//
//  CoachChatViewModel.swift
//  FitLog
//
//  @Observable view model for the free-form Coach tab chat.
//

import Foundation
import Observation
import SwiftUI

private enum CoachChatLimits {
    static let maxMessageChars = 800
    static let maxAPIConversationMessages = 24
    static let sendCooldown: TimeInterval = 2
    static let streamPersistDebounce: TimeInterval = 0.5
}

@Observable @MainActor
final class CoachChatViewModel {
    private(set) var messages: [CoachChatMessage] = []
    private(set) var conversations: [CoachConversationSummary] = []
    private(set) var currentConversationID: UUID?
    private(set) var isSending = false
    private(set) var isStreaming = false
    private(set) var cooldownActive = false
    private(set) var starterPrompts: [String] = []

    var draft = ""
    var errorBanner: String?
    var showRetry = false
    var contextSummary = CoachContextSummary(
        todayPlan: "",
        programSummary: "",
        workoutCount: 0,
        recentSessionCount: 0,
        sessionsThisWeek: 0,
        wasTruncated: false
    )

    var sendFeedbackCount = 0
    var receiveFeedbackCount = 0

    private var didBootstrap = false
    private var cachedContextSnapshot = ""
    private var lastSendTime: Date?
    private var sendTask: Task<Void, Never>?
    private var lastFailedUserText: String?
    private var lastStreamPersistTask: Task<Void, Never>?
    private var streamingAssistantPersisted = false

    var canSend: Bool {
        !isSending && !cooldownActive && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isConversationEmpty: Bool { messages.isEmpty }

    // MARK: - Bootstrap

    func bootstrap(dataVM: DataManager) {
        refreshContext(dataVM: dataVM)
        guard !didBootstrap else { return }
        didBootstrap = true

        dataVM.coachChatStore.pruneEmptyConversations()
        conversations = dataVM.coachChatStore.loadConversations()

        if let recent = conversations.first {
            loadConversation(id: recent.id, dataVM: dataVM)
        } else {
            currentConversationID = nil
            messages = []
        }
    }

    func refreshContext(dataVM: DataManager) {
        contextSummary = CoachContextSummaryBuilder.build(dataVM: dataVM)
        cachedContextSnapshot = dataVM.coachDataContextSnapshot()
        starterPrompts = CoachStarterPromptGenerator.prompts(dataVM: dataVM)
    }

    // MARK: - Conversations

    func startNewConversation(dataVM: DataManager) {
        cancelSend(dataVM: dataVM)
        currentConversationID = nil
        messages = []
        draft = ""
        errorBanner = nil
        showRetry = false
    }

    func loadConversation(id: UUID, dataVM: DataManager) {
        cancelSend(dataVM: dataVM)
        currentConversationID = id
        messages = dataVM.coachChatStore.loadMessages(conversationID: id)
        draft = ""
        errorBanner = nil
        showRetry = false
    }

    func deleteConversation(id: UUID, dataVM: DataManager) {
        dataVM.coachChatStore.deleteConversation(id: id)
        refreshConversations(dataVM: dataVM)
        if currentConversationID == id {
            if let next = conversations.first {
                loadConversation(id: next.id, dataVM: dataVM)
            } else {
                startNewConversation(dataVM: dataVM)
            }
        }
    }

    func renameConversation(id: UUID, title: String, dataVM: DataManager) {
        dataVM.coachChatStore.renameConversation(id: id, title: title)
        refreshConversations(dataVM: dataVM)
    }

    func clearCurrentConversation(dataVM: DataManager) {
        guard let id = currentConversationID else {
            messages = []
            draft = ""
            return
        }
        dataVM.coachChatStore.clearConversationMessages(conversationID: id)
        messages = []
        draft = ""
        errorBanner = nil
        showRetry = false
        refreshConversations(dataVM: dataVM)
    }

    // MARK: - Send

    func sendStarter(_ text: String, dataVM: DataManager, aiService: AIService, entitlementStore: EntitlementStore) {
        draft = text
        send(dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore)
    }

    func send(dataVM: DataManager, aiService: AIService, entitlementStore: EntitlementStore, regenerateFrom assistantID: UUID? = nil) {
        let trimmed: String
        let skipNewUserMessage: Bool

        if let assistantID,
           let assistantIndex = messages.firstIndex(where: { $0.id == assistantID }),
           let userIndex = messages[..<assistantIndex].lastIndex(where: { $0.role == .user }) {
            trimmed = messages[userIndex].text
            skipNewUserMessage = true
            let toRemove = Array(messages[assistantIndex...])
            messages.removeSubrange(assistantIndex...)
            if let conversationID = currentConversationID {
                for msg in toRemove {
                    dataVM.coachChatStore.deleteMessage(id: msg.id, conversationID: conversationID)
                }
            }
        } else {
            trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            skipNewUserMessage = false
        }

        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= CoachChatLimits.maxMessageChars else {
            errorBanner = "Message is too long (max \(CoachChatLimits.maxMessageChars) characters)."
            return
        }
        if let last = lastSendTime, Date().timeIntervalSince(last) < CoachChatLimits.sendCooldown {
            beginCooldown()
            return
        }

        guard entitlementStore.hasAccess(to: .aiCoach) else {
            errorBanner = "Upgrade to Premium to chat with AI Coach."
            AnalyticsService.shared.track(.aiBlockedByPaywall, properties: ["feature": PremiumFeature.aiCoach.rawValue])
            return
        }

        guard aiService.isConfigured else {
            errorBanner = AIServiceError.notConfigured.errorDescription
            return
        }

        ensureConversation(dataVM: dataVM)
        guard let conversationID = currentConversationID else { return }

        errorBanner = nil
        showRetry = false
        isSending = true
        isStreaming = false
        lastSendTime = Date()
        sendFeedbackCount += 1

        if !skipNewUserMessage {
            let userMsg = CoachChatMessage(role: .user, text: trimmed)
            appendMessage(userMsg, conversationID: conversationID, dataVM: dataVM, refreshList: false)
            draft = ""
        }

        let apiTurns = buildAPITurns()
        lastFailedUserText = trimmed
        let snapshot = cachedContextSnapshot.isEmpty
            ? dataVM.coachDataContextSnapshot()
            : cachedContextSnapshot

        streamingAssistantPersisted = false
        sendTask = Task {
            await performSend(
                apiTurns: apiTurns,
                snapshot: snapshot,
                conversationID: conversationID,
                dataVM: dataVM,
                aiService: aiService,
                addedUserMessageThisSend: !skipNewUserMessage
            )
        }
    }

    func retryLastSend(dataVM: DataManager, aiService: AIService, entitlementStore: EntitlementStore) {
        guard let trimmed = lastFailedUserText else { return }
        if let lastUser = messages.last(where: { $0.role == .user }), lastUser.text == trimmed {
            messages.removeAll { $0.id == lastUser.id }
            if let id = currentConversationID {
                dataVM.coachChatStore.deleteMessage(id: lastUser.id, conversationID: id)
            }
        }
        draft = trimmed
        showRetry = false
        errorBanner = nil
        send(dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore)
    }

    func cancelSend(dataVM: DataManager) {
        sendTask?.cancel()
        sendTask = nil
        lastStreamPersistTask?.cancel()
        lastStreamPersistTask = nil
        isSending = false
        isStreaming = false
        if let idx = messages.lastIndex(where: { $0.status == .streaming }) {
            var msg = messages[idx]
            if msg.text.isEmpty {
                messages.remove(at: idx)
                if let conversationID = currentConversationID {
                    dataVM.coachChatStore.deleteMessage(id: msg.id, conversationID: conversationID)
                }
            } else {
                let parsed = AIService.parseStructuredCoachResponse(msg.text)
                msg.text = parsed.reply
                msg.actions = parsed.actions
                msg.status = .sent
                messages[idx] = msg
                if let conversationID = currentConversationID {
                    persistAssistantMessage(msg, conversationID: conversationID, dataVM: dataVM, alreadyPersisted: streamingAssistantPersisted)
                }
            }
        }
        refreshConversations(dataVM: dataVM)
    }

    func setFeedback(_ feedback: CoachMessageFeedback?, messageID: UUID, dataVM: DataManager) {
        guard let conversationID = currentConversationID,
              let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].feedback = feedback
        dataVM.coachChatStore.setFeedback(messageID: messageID, conversationID: conversationID, feedback: feedback)
    }

    func markActionApplied(actionID: UUID, messageID: UUID) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageID }),
              let actionIndex = messages[msgIndex].actions.firstIndex(where: { $0.id == actionID }) else { return }
        let action = messages[msgIndex].actions[actionIndex]
        messages[msgIndex].actions[actionIndex] = CoachChatAction(
            id: action.id,
            kind: action.kind,
            title: action.title,
            detail: action.detail,
            prefill: action.prefill,
            isApplied: true
        )
    }

    // MARK: - Private

    private func refreshConversations(dataVM: DataManager) {
        conversations = dataVM.coachChatStore.loadConversations()
    }

    private func ensureConversation(dataVM: DataManager) {
        guard currentConversationID == nil else { return }
        currentConversationID = dataVM.coachChatStore.createConversation()
    }

    private func appendMessage(
        _ message: CoachChatMessage,
        conversationID: UUID,
        dataVM: DataManager,
        refreshList: Bool
    ) {
        messages.append(message)
        trimMessagesIfNeeded(dataVM: dataVM, conversationID: conversationID)
        dataVM.coachChatStore.appendMessage(message, conversationID: conversationID)
        if refreshList {
            refreshConversations(dataVM: dataVM)
        }
    }

    private func trimMessagesIfNeeded(dataVM: DataManager, conversationID: UUID) {
        let maxCount = CoachChatStoreLimits.maxConversationMessages
        guard messages.count > maxCount else { return }
        let overflow = messages.prefix(messages.count - maxCount)
        for msg in overflow {
            dataVM.coachChatStore.deleteMessage(id: msg.id, conversationID: conversationID)
        }
        messages = Array(messages.suffix(maxCount))
    }

    private func buildAPITurns() -> [(role: String, content: String)] {
        let tail = Array(messages.suffix(CoachChatLimits.maxAPIConversationMessages))
        return tail.map { ($0.role == .user ? "user" : "assistant", $0.text) }
    }

    private func beginCooldown() {
        cooldownActive = true
        Task {
            try? await Task.sleep(for: .seconds(CoachChatLimits.sendCooldown))
            cooldownActive = false
        }
    }

    private func displayTextForStreaming(_ accumulated: String) -> String {
        AIService.stripPartialCoachJSONFenceForDisplay(accumulated)
    }

    private func upsertStreamingAssistant(_ assistant: inout CoachChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == assistant.id }) {
            messages[index] = assistant
        } else {
            messages.append(assistant)
        }
    }

    private func persistAssistantMessage(
        _ assistant: CoachChatMessage,
        conversationID: UUID,
        dataVM: DataManager,
        alreadyPersisted: Bool
    ) {
        if alreadyPersisted {
            dataVM.coachChatStore.updateMessage(assistant, conversationID: conversationID)
        } else {
            dataVM.coachChatStore.appendMessage(assistant, conversationID: conversationID)
        }
    }

    private func scheduleDebouncedStreamPersist(
        assistant: CoachChatMessage,
        conversationID: UUID,
        dataVM: DataManager,
        alreadyPersisted: Bool
    ) {
        let willAppend = !alreadyPersisted
        lastStreamPersistTask?.cancel()
        let snapshot = assistant
        lastStreamPersistTask = Task {
            try? await Task.sleep(for: .seconds(CoachChatLimits.streamPersistDebounce))
            guard !Task.isCancelled else { return }
            var msg = snapshot
            msg.status = .streaming
            if willAppend {
                dataVM.coachChatStore.appendMessage(msg, conversationID: conversationID)
            } else {
                dataVM.coachChatStore.updateMessage(msg, conversationID: conversationID)
            }
        }
        streamingAssistantPersisted = true
    }

    private func performSend(
        apiTurns: [(role: String, content: String)],
        snapshot: String,
        conversationID: UUID,
        dataVM: DataManager,
        aiService: AIService,
        addedUserMessageThisSend: Bool
    ) async {
        var assistant = CoachChatMessage(role: .assistant, text: "", status: .streaming)
        var assistantCreated = false
        var accumulated = ""

        do {
            let stream = aiService.coachChatStream(conversation: apiTurns, contextSnapshot: snapshot)
            for try await chunk in stream {
                try Task.checkCancellation()
                accumulated += chunk

                if !assistantCreated {
                    isStreaming = true
                    assistantCreated = true
                }
                assistant.text = displayTextForStreaming(accumulated)
                upsertStreamingAssistant(&assistant)
                scheduleDebouncedStreamPersist(
                    assistant: assistant,
                    conversationID: conversationID,
                    dataVM: dataVM,
                    alreadyPersisted: streamingAssistantPersisted
                )
            }

            if accumulated.isEmpty {
                let structured = try await aiService.coachChatStructured(conversation: apiTurns, contextSnapshot: snapshot)
                accumulated = structured.reply
                assistant.text = structured.reply
                assistant.actions = structured.actions
                if !assistantCreated {
                    isStreaming = true
                    assistantCreated = true
                    upsertStreamingAssistant(&assistant)
                }
            } else {
                let parsed = AIService.parseStructuredCoachResponse(accumulated)
                assistant.text = parsed.reply
                assistant.actions = parsed.actions
            }

            lastStreamPersistTask?.cancel()
            lastStreamPersistTask = nil
            assistant.status = .sent
            upsertStreamingAssistant(&assistant)
            persistAssistantMessage(assistant, conversationID: conversationID, dataVM: dataVM, alreadyPersisted: streamingAssistantPersisted)
            trimMessagesIfNeeded(dataVM: dataVM, conversationID: conversationID)
            receiveFeedbackCount += 1
            errorBanner = nil
            showRetry = false
        } catch is CancellationError {
            lastStreamPersistTask?.cancel()
            lastStreamPersistTask = nil
            if assistantCreated {
                if assistant.text.isEmpty {
                    messages.removeAll { $0.id == assistant.id }
                    if streamingAssistantPersisted {
                        dataVM.coachChatStore.deleteMessage(id: assistant.id, conversationID: conversationID)
                    }
                } else {
                    let parsed = AIService.parseStructuredCoachResponse(accumulated)
                    assistant.text = parsed.reply
                    assistant.actions = parsed.actions
                    assistant.status = .sent
                    upsertStreamingAssistant(&assistant)
                    persistAssistantMessage(assistant, conversationID: conversationID, dataVM: dataVM, alreadyPersisted: streamingAssistantPersisted)
                }
            }
        } catch {
            lastStreamPersistTask?.cancel()
            lastStreamPersistTask = nil
            if assistantCreated {
                messages.removeAll { $0.id == assistant.id }
                if streamingAssistantPersisted {
                    dataVM.coachChatStore.deleteMessage(id: assistant.id, conversationID: conversationID)
                }
            }
            if addedUserMessageThisSend, let lastUser = messages.last(where: { $0.role == .user }) {
                messages.removeAll { $0.id == lastUser.id }
                dataVM.coachChatStore.deleteMessage(id: lastUser.id, conversationID: conversationID)
                draft = lastUser.text
            }
            errorBanner = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showRetry = true
        }

        isSending = false
        isStreaming = false
        sendTask = nil
        refreshConversations(dataVM: dataVM)
    }
}
