//
//  AIChatView.swift
//  FitLog
//
//  In-app coach chat scoped to FitLog data; persisted threads + streaming.
//

import SwiftUI
import UIKit

struct AIChatView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.fitlogCoachDeepLink) private var coachDeepLink
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection

    @State private var viewModel = CoachChatViewModel()
    @FocusState private var isComposerFocused: Bool
    @State private var showProgramBuilder = false
    @State private var programBuilderPrefill: String?
    @State private var showHistory = false
    @State private var showContextSheet = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if shouldShowCoachPremiumBanner, !viewModel.isConversationEmpty {
                    premiumRequiredBanner
                } else if entitlementStore.isPremium, !aiService.isConfigured {
                    notConfiguredBanner
                }

                if let err = viewModel.errorBanner {
                    errorBannerView(err)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewModel.isConversationEmpty {
                                localTipCard(localCoachTip)
                                if shouldShowCoachPremiumBanner {
                                    compactCoachUnlockCard
                                } else if entitlementStore.isPremium {
                                    emptyStateHero
                                }
                            }

                            ForEach(viewModel.messages) { msg in
                                messageRow(msg)
                                    .id(msg.id)
                            }

                            if viewModel.isSending && !viewModel.isStreaming {
                                typingIndicator
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                    .defaultScrollAnchor(viewModel.isConversationEmpty ? .top : .bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isStreaming) { _, streaming in
                        if streaming { scrollToBottom(proxy: proxy) }
                    }
                    .onChange(of: viewModel.messages.last?.text) { _, _ in
                        if viewModel.isStreaming { scrollToBottom(proxy: proxy) }
                    }
                }

                if viewModel.isConversationEmpty, entitlementStore.isPremium {
                    starterChips
                }

                disclaimerFooter

                composer
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissCoachKeyboard() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
            .sheet(isPresented: $showProgramBuilder, onDismiss: { programBuilderPrefill = nil }) {
                SplitBuilderView()
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
                    .environment(\.fitlogRootTabSelection, rootTabSelection)
                    .environment(\.fitlogAISplitCoachPrefill, programBuilderPrefill)
            }
            .sheet(isPresented: $showHistory) {
                CoachConversationHistorySheet(
                    conversations: viewModel.conversations,
                    currentID: viewModel.currentConversationID,
                    onSelect: { id in viewModel.loadConversation(id: id, dataVM: dataVM) },
                    onDelete: { id in viewModel.deleteConversation(id: id, dataVM: dataVM) },
                    onRename: { id, title in viewModel.renameConversation(id: id, title: title, dataVM: dataVM) },
                    onNewChat: { viewModel.startNewConversation(dataVM: dataVM) }
                )
            }
            .sheet(isPresented: $showContextSheet) {
                CoachContextSheet(summary: viewModel.contextSummary)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    triggerFeature: .aiCoach,
                    analyticsSource: "ai_chat"
                )
                .environment(entitlementStore)
            }
            .onAppear {
                viewModel.bootstrap(dataVM: dataVM)
            }
            .onChange(of: coachDeepLink.wrappedValue, initial: true) { _, new in
                switch new {
                case .openDynamicProgramBuilder(let prefill):
                    programBuilderPrefill = prefill
                    showProgramBuilder = true
                    coachDeepLink.wrappedValue = .idle
                case .idle:
                    break
                }
            }
            .sensoryFeedback(.selection, trigger: viewModel.sendFeedbackCount)
            .sensoryFeedback(.success, trigger: viewModel.receiveFeedbackCount)
        }
    }

    // MARK: - Toolbar

    private var overflowMenu: some View {
        Menu {
            Button {
                viewModel.startNewConversation(dataVM: dataVM)
            } label: {
                Label("New chat", systemImage: "plus.bubble")
            }

            Button {
                showHistory = true
            } label: {
                Label("Chat history", systemImage: "clock.arrow.circlepath")
            }

            Button {
                programBuilderPrefill = nil
                showProgramBuilder = true
            } label: {
                Label("Program builder", systemImage: "calendar.badge.clock")
            }

            Button {
                showContextSheet = true
            } label: {
                Label("What your coach sees", systemImage: "eye")
            }

            Divider()

            Button(role: .destructive) {
                dismissCoachKeyboard()
                viewModel.clearCurrentConversation(dataVM: dataVM)
            } label: {
                Label("Clear chat", systemImage: "trash")
            }
            .disabled(viewModel.isConversationEmpty && viewModel.draft.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Coach options")
    }

    // MARK: - Messages

    @ViewBuilder
    private func messageRow(_ msg: CoachChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachChatBubbleView(
                message: msg,
                onCopy: { UIPasteboard.general.string = msg.text },
                onRegenerate: msg.role == .assistant ? {
                    viewModel.send(dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore, regenerateFrom: msg.id)
                } : nil,
                onFeedback: { feedback in
                    viewModel.setFeedback(feedback, messageID: msg.id, dataVM: dataVM)
                }
            )

            if !msg.actions.isEmpty {
                ForEach(msg.actions) { action in
                    CoachChatActionCardView(action: action) {
                        applyAction(action, messageID: msg.id)
                    }
                }
                .padding(.leading, 36)
            }
        }
    }

    private func applyAction(_ action: CoachChatAction, messageID: UUID) {
        switch action.kind {
        case .openProgramBuilder:
            programBuilderPrefill = action.prefill
            showProgramBuilder = true
        case .openPlanTab:
            rootTabSelection?.wrappedValue = .plan
        case .openHomeTab:
            rootTabSelection?.wrappedValue = .home
        }
        viewModel.markActionApplied(actionID: action.id, messageID: messageID)
    }

    // MARK: - Empty state

    private var shouldShowCoachPremiumBanner: Bool {
        guard !entitlementStore.isPremium else { return false }
        return !dataVM.userWorkouts.isEmpty || dataVM.dynamicProgramState != nil
    }

    private var localCoachTip: CoachLocalTip {
        CoachLocalTipGenerator.tip(from: CoachLocalTipGenerator.makeContext(dataVM: dataVM))
    }

    private func localTipCard(_ tip: CoachLocalTip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tip.title, systemImage: "lightbulb")
                .font(.title3.weight(.semibold))
            Text(tip.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("On-device tip from your log. Not medical advice.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tip.title). \(tip.body)")
        .accessibilityHint("Local coaching tip generated on this device from your workout log")
    }

    private var compactCoachUnlockCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Want AI coaching on this tip?")
                .font(.subheadline.weight(.semibold))
            Text("Premium unlocks natural-language Coach replies. The tip above is free and stays on-device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("View Premium") { showPaywall = true }
                .font(.caption.weight(.semibold))
                .accessibilityHint("Shows subscription options for AI Coach")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var emptyStateHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your training coach", systemImage: "figure.strengthtraining.traditional")
                .font(.title3.weight(.semibold))
            Text("Ask about your plan, workouts, exercises, or recent training. I'll use your logged data to give practical advice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if viewModel.contextSummary.sessionsThisWeek > 0 {
                Text("You've logged \(viewModel.contextSummary.sessionsThisWeek) session\(viewModel.contextSummary.sessionsThisWeek == 1 ? "" : "s") in the last 7 days.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .accessibilityElement(children: .combine)
    }

    private var disclaimerFooter: some View {
        Text("Not medical advice. AI can be wrong—verify important changes.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 4)
            .accessibilityLabel("Disclaimer. Not medical advice. AI can be wrong. Verify important changes.")
    }

    // MARK: - Banners & indicators

    private var premiumRequiredBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Premium AI Coach", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Text("Unlock natural-language coaching, program generation, and personalized explanations with Premium. On Apple Intelligence devices, short coaching can run privately on-device.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let availability = AIRoutingService.shared.availabilityBannerText {
                Text(availability)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Button("View Premium") { showPaywall = true }
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.12))
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

    private func errorBannerView(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            if viewModel.showRetry {
                Button("Retry") {
                    viewModel.retryLastSend(dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var typingIndicator: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitlogPalette.chartPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(FitlogPalette.subtleFill))
                .accessibilityHidden(true)

            CoachTypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(FitlogPalette.subtleFill)
                )
            Spacer(minLength: 48)
        }
        .accessibilityLabel("Coach is thinking")
    }

    // MARK: - Starters & composer

    private var starterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.starterPrompts, id: \.self) { title in
                    Button(title) {
                        guard requirePremiumOrPaywall(feature: .aiCoach, entitlementStore: entitlementStore, showPaywall: $showPaywall) else { return }
                        viewModel.sendStarter(title, dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore)
                    }
                    .disabled(!entitlementStore.isPremium || !aiService.isConfigured || viewModel.isSending)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .accessibilityHint("Send this starter question")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your training…", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isComposerFocused)
                .onChange(of: viewModel.draft) { _, new in
                    if new.count > 800 {
                        viewModel.draft = String(new.prefix(800))
                    }
                }
                .accessibilityLabel("Message")
                .accessibilityHint("Ask your coach about your training")

            if viewModel.isSending {
                Button {
                    viewModel.cancelSend(dataVM: dataVM)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Stop")
                .accessibilityHint("Stop the current response")
            } else {
                Button {
                    guard requirePremiumOrPaywall(feature: .aiCoach, entitlementStore: entitlementStore, showPaywall: $showPaywall) else { return }
                    viewModel.send(dataVM: dataVM, aiService: aiService, entitlementStore: entitlementStore)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(!viewModel.canSend || !entitlementStore.isPremium || !aiService.isConfigured)
                .accessibilityLabel("Send")
                .accessibilityHint("Send your message to the coach")
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Helpers

    private func dismissCoachKeyboard() {
        isComposerFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if viewModel.isSending, !viewModel.isStreaming {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
