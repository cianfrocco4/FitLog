//
//  CoachConversationView.swift
//  FitLog
//
//  Main Guided Coach conversational program builder UI.
//

import SwiftUI

struct CoachConversationView: View {
    @Bindable var coachVM: CoachConversationViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(DataManager.self) private var dataManager
    @Environment(EntitlementStore.self) private var entitlementStore
    @FocusState private var isReviewComposerFocused: Bool
    @State private var showPaywall = false
    @State private var paywallTrigger: PremiumFeature = .aiCoach

    var body: some View {
        VStack(spacing: 0) {
            if let error = coachVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(coachVM.messages) { message in
                            messageView(for: message)
                                .id(message.id)
                        }

                        if let topic = coachVM.pendingIntakeTopic {
                            intakeInput(for: topic)
                                .id("intake-input")
                        }

                        if coachVM.phase == .recommendations, let blueprint = coachVM.blueprint {
                            if coachVM.messages.contains(where: { if case .recommendationCards = $0.kind { return true }; return false }) {
                                CoachRecommendationCardsSection(
                                    recommendations: blueprint.recommendations,
                                    activeDiscussTopic: coachVM.activeDiscussTopic,
                                    threadProvider: { coachVM.thread(for: $0) },
                                    draftProvider: { coachVM.draft(for: $0) },
                                    shouldFocusComposer: { coachVM.focusedDiscussTopic == $0 },
                                    onAccept: { coachVM.acceptRecommendation($0) },
                                    onAdjust: { topic, value in coachVM.applyRecommendationOverride(topic: topic, newValue: value) },
                                    onDiscuss: { coachVM.beginDiscuss(topic: $0) },
                                    onSendDiscuss: { topic in
                                        guard entitlementStore.hasAccess(to: .aiCoach) else {
                                            paywallTrigger = .aiCoach
                                            showPaywall = true
                                            return
                                        }
                                        Task { await coachVM.submitFollowUp(for: topic, aiService: aiService) }
                                    },
                                    onApplySuggestion: { topic, change in
                                        coachVM.applySuggestedChange(change, in: topic)
                                    },
                                    onDoneDiscuss: { coachVM.endDiscuss(topic: $0) },
                                    onAcceptAll: { coachVM.acceptAllRecommendations() }
                                )
                                .id("recommendation-cards")
                            }
                        }

                        if coachVM.phase == .review, let blueprint = coachVM.blueprint {
                            CoachBlueprintSummary(
                                blueprint: blueprint,
                                onBuild: {
                                    guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
                                        paywallTrigger = .aiProgramGeneration
                                        showPaywall = true
                                        return
                                    }
                                    Task {
                                        await coachVM.buildProgram(aiService: aiService, dataManager: dataManager, entitlementStore: entitlementStore)
                                    }
                                },
                                isLoading: false
                            )
                            .id("blueprint-summary")
                        }

                        if coachVM.phase == .generating, let blueprint = coachVM.blueprint {
                            CoachProgramGenerationProgressView(
                                statusMessage: coachVM.generationStatusLine,
                                isConnecting: coachVM.builderViewModel.isConnectingToProxy,
                                blockCompleted: coachVM.builderViewModel.generationBlockCompleted,
                                blockTotal: coachVM.builderViewModel.generationBlockTotal,
                                programTitle: blueprint.programName,
                                daysPerWeek: blueprint.sessionsPerWeek
                            )
                            .id("generation-progress")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, showReviewComposer ? 8 : 0)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: coachVM.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: coachVM.phase) { _, phase in
                    scrollForPhase(phase: phase, proxy: proxy)
                }
                .onChange(of: coachVM.scrollToGenerationTrigger) { _, _ in
                    scrollToGenerationProgress(proxy: proxy)
                }
                .onChange(of: coachVM.builderViewModel.generationStatusMessage) { _, _ in
                    guard coachVM.phase == .generating else { return }
                    scrollToGenerationProgress(proxy: proxy)
                }
                .onChange(of: coachVM.activeDiscussTopic) { _, topic in
                    guard let topic else { return }
                    scrollToDiscussCard(topic: topic, proxy: proxy)
                }
                .onChange(of: coachVM.discussScrollTrigger) { _, _ in
                    if let topic = coachVM.activeDiscussTopic {
                        scrollToDiscussCard(topic: topic, proxy: proxy)
                    }
                }
            }

            if showReviewComposer {
                reviewComposerBar
            }
        }
        .navigationTitle("Guided Coach")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $coachVM.navigateToReview) {
            DynamicProgramBuilderView(viewModel: coachVM.builderViewModel, hidesBuilderModePicker: true)
        }
        .onAppear {
            coachVM.bootstrap(dataManager: dataManager)
        }
        .task(id: coachVM.phase) {
            if coachVM.phase == .recommendations, coachVM.blueprint != nil, entitlementStore.hasAccess(to: .aiCoach) {
                await coachVM.enrichRecommendationsWithAI(aiService: aiService)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: paywallTrigger)
                .environment(entitlementStore)
        }
        .sensoryFeedback(.selection, trigger: coachVM.selectionFeedbackCount)
        .sensoryFeedback(.success, trigger: coachVM.builderViewModel.generationSuccessCount)
    }

    @ViewBuilder
    private func messageView(for message: CoachMessage) -> some View {
        switch message.kind {
        case .recommendationCards, .blueprintSummary, .intakePrompt:
            EmptyView()
        case .changeSummary(let changes):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(changes) { change in
                    Label(change.diffDescription, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        default:
            CoachMessageBubble(message: message)
        }
    }

    @ViewBuilder
    private func intakeInput(for topic: CoachIntakeTopic) -> some View {
        switch topic {
        case .schedule:
            CoachScheduleInput(
                sessions: $coachVM.scheduleSessions,
                weekdays: $coachVM.scheduleWeekdays,
                onSubmit: { coachVM.submitScheduleAnswer() }
            )
        case .constraints:
            VStack(alignment: .leading, spacing: 10) {
                CoachQuickReplyPills(options: ["None"]) { value in
                    coachVM.draftText = value
                    coachVM.submitConstraintsAnswer()
                }
                TextField("Optional details", text: $coachVM.draftText, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.roundedBorder)
                Button("Continue") { coachVM.submitConstraintsAnswer() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FitlogPalette.subtleFill)
            )
        default:
            CoachQuickReplyPills(options: coachVM.quickRepliesForPendingQuestion()) { value in
                coachVM.submitQuickReply(value)
            }
        }
    }

    private var showReviewComposer: Bool {
        coachVM.phase == .review && coachVM.pendingIntakeTopic == nil
    }

    private var reviewComposerBar: some View {
        HStack(spacing: 10) {
            TextField("Any final notes?", text: $coachVM.draftText, axis: .vertical)
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .focused($isReviewComposerFocused)

            Button {
                if !coachVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    coachVM.appendFinalNotes(coachVM.draftText)
                    coachVM.draftText = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(coachVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Save final notes")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        scrollForPhase(phase: coachVM.phase, proxy: proxy)
    }

    private func scrollForPhase(phase: CoachPhase, proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.22)) {
            if phase == .generating {
                proxy.scrollTo("generation-progress", anchor: .center)
            } else if phase == .review {
                proxy.scrollTo("blueprint-summary", anchor: .bottom)
            } else if phase == .recommendations, coachVM.activeDiscussTopic == nil {
                proxy.scrollTo("recommendation-cards", anchor: .bottom)
            } else if let last = coachVM.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func scrollToGenerationProgress(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("generation-progress", anchor: .center)
        }
    }

    private func scrollToDiscussCard(topic: CoachRecommendationTopic, proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.24)) {
                proxy.scrollTo("recommendation-\(topic.rawValue)", anchor: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CoachConversationView(coachVM: CoachConversationViewModel(builderViewModel: DynamicProgramBuilderViewModel()))
    }
    .environment(EntitlementStore())
}
