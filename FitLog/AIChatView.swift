//
//  AIChatView.swift
//  FitLog
//
//  In-app coach chat scoped to FitLog data; client limits + strict system prompt.
//

import SwiftUI
import UIKit

private enum CoachChatLimits {
    static let maxMessageChars = 800
    static let maxStoredMessages = 40
    static let maxAPIConversationMessages = 24
    static let sendCooldown: TimeInterval = 2
}

struct CoachChatMessage: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool
    let text: String
    let created: Date

    init(id: UUID = UUID(), isUser: Bool, text: String, created: Date = Date()) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.created = created
    }
}

@MainActor
final class CoachChatController: ObservableObject {
    @Published private(set) var messages: [CoachChatMessage] = []
    @Published var draft = ""
    @Published private(set) var isSending = false
    @Published var errorBanner: String?

    private var lastSendTime: Date?

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearChat() {
        messages = []
        errorBanner = nil
        draft = ""
    }

    func sendStarter(_ text: String, dataVM: DataManager, aiService: AIService) async {
        draft = text
        await send(dataVM: dataVM, aiService: aiService)
    }

    func send(dataVM: DataManager, aiService: AIService) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= CoachChatLimits.maxMessageChars else {
            errorBanner = "Message is too long (max \(CoachChatLimits.maxMessageChars) characters)."
            return
        }
        if let last = lastSendTime, Date().timeIntervalSince(last) < CoachChatLimits.sendCooldown {
            errorBanner = "Please wait a moment before sending another message."
            return
        }

        errorBanner = nil
        isSending = true
        lastSendTime = Date()

        let userMsg = CoachChatMessage(isUser: true, text: trimmed)
        messages.append(userMsg)
        draft = ""

        if messages.count > CoachChatLimits.maxStoredMessages {
            messages = Array(messages.suffix(CoachChatLimits.maxStoredMessages))
        }

        let snapshot = dataVM.coachDataContextSnapshot()
        let tail = Array(messages.suffix(CoachChatLimits.maxAPIConversationMessages))
        var apiTurns: [(role: String, content: String)] = []
        for m in tail {
            apiTurns.append((m.isUser ? "user" : "assistant", m.text))
        }

        do {
            let reply = try await aiService.coachChat(conversation: apiTurns, contextSnapshot: snapshot)
            let assistantMsg = CoachChatMessage(isUser: false, text: reply)
            messages.append(assistantMsg)
            if messages.count > CoachChatLimits.maxStoredMessages {
                messages = Array(messages.suffix(CoachChatLimits.maxStoredMessages))
            }
        } catch {
            errorBanner = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            messages.removeAll { $0.id == userMsg.id }
            draft = trimmed
        }

        isSending = false
    }
}

struct AIChatView: View {
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.fitlogCoachDeepLink) private var coachDeepLink

    @StateObject private var chat = CoachChatController()
    @FocusState private var isComposerFocused: Bool
    @State private var showSplitBuilder = false
    @State private var splitBuilderPrefill: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !aiService.isConfigured {
                    notConfiguredBanner
                }

                if let err = chat.errorBanner {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            introBlock

                            ForEach(chat.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }

                            if chat.isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .id("typing")
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chat.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chat.isSending) { _, sending in
                        if sending { scrollToBottom(proxy: proxy) }
                    }
                }

                starterChips

                composer
            }
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissCoachKeyboard() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if isComposerFocused {
                            Button("Done") { dismissCoachKeyboard() }
                        }
                        Button {
                            splitBuilderPrefill = nil
                            showSplitBuilder = true
                        } label: {
                            Label("AI split builder", systemImage: "sparkles")
                        }
                        Button("Clear") {
                            dismissCoachKeyboard()
                            chat.clearChat()
                        }
                        .disabled(chat.messages.isEmpty && chat.draft.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showSplitBuilder) {
                AISplitBuilderView()
                    .environmentObject(dataVM)
                    .environmentObject(aiService)
                    .environment(\.fitlogAISplitCoachPrefill, splitBuilderPrefill)
            }
            .onChange(of: coachDeepLink.wrappedValue) { _, new in
                if case .openAISplitBuilder(let prefill) = new {
                    splitBuilderPrefill = prefill
                    showSplitBuilder = true
                    coachDeepLink.wrappedValue = .idle
                }
            }
        }
    }

    private func dismissCoachKeyboard() {
        isComposerFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var notConfiguredBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI not configured", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("Add an API key or proxy URL in your scheme (see project docs) to use the coach.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.15))
    }

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask about your plan, workouts, exercises, or recent training. I only help with FitLog-related strength training—not medical advice, general chat, or unrelated topics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Not medical advice. AI can be wrong—verify important changes.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func messageBubble(_ msg: CoachChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 48) }
            Text(msg.text)
                .font(.body)
                .padding(12)
                .background(msg.isUser ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !msg.isUser { Spacer(minLength: 48) }
        }
    }

    private var starterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(starters, id: \.self) { title in
                    Button(title) {
                        Task {
                            await chat.sendStarter(title, dataVM: dataVM, aiService: aiService)
                        }
                    }
                    .disabled(!aiService.isConfigured || chat.isSending)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var starters: [String] {
        [
            "How can I improve my workout split?",
            "Review my busiest workout day for balance",
            "Suggest a small change for recovery",
            "What should I focus on this week based on my log?"
        ]
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your training…", text: $chat.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isComposerFocused)
                .onChange(of: chat.draft) { _, new in
                    if new.count > CoachChatLimits.maxMessageChars {
                        chat.draft = String(new.prefix(CoachChatLimits.maxMessageChars))
                    }
                }

            Button {
                Task {
                    await chat.send(dataVM: dataVM, aiService: aiService)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(!chat.canSend || !aiService.isConfigured)
            .accessibilityLabel("Send")
        }
        .padding()
        .background(.bar)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if chat.isSending {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let last = chat.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
