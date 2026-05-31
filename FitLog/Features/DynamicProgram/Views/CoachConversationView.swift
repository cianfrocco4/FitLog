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
    @FocusState private var isComposerFocused: Bool

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
                                    onAccept: { coachVM.acceptRecommendation($0) },
                                    onAdjust: { topic, value in coachVM.applyRecommendationOverride(topic: topic, newValue: value) },
                                    onDiscuss: { coachVM.beginDiscuss(topic: $0) },
                                    onAcceptAll: { coachVM.acceptAllRecommendations() }
                                )
                                .id("recommendation-cards")
                            }
                        }

                        if coachVM.phase == .review, let blueprint = coachVM.blueprint {
                            CoachBlueprintSummary(
                                blueprint: blueprint,
                                onBuild: {
                                    Task {
                                        await coachVM.buildProgram(aiService: aiService, dataManager: dataManager)
                                    }
                                },
                                isLoading: coachVM.phase == .generating
                            )
                            .id("blueprint-summary")
                        }

                        if !coachVM.pendingFollowUpSuggestions.isEmpty {
                            followUpSuggestions
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: coachVM.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: coachVM.phase) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            if showComposer {
                composerBar
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
            if coachVM.phase == .recommendations, coachVM.blueprint != nil {
                await coachVM.enrichRecommendationsWithAI(aiService: aiService)
            }
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

    private var followUpSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested changes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(coachVM.pendingFollowUpSuggestions, id: \.topic) { suggestion in
                Button {
                    coachVM.applySuggestedChange(suggestion)
                } label: {
                    HStack {
                        Text("Apply: \(suggestion.suggestedValue)")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Apply this suggested change")
            }
        }
    }

    private var showComposer: Bool {
        coachVM.discussingTopic != nil
            || (coachVM.phase == .review && coachVM.pendingIntakeTopic == nil)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField(
                coachVM.discussingTopic != nil ? "Ask the coach…" : "Any final notes?",
                text: $coachVM.draftText,
                axis: .vertical
            )
            .lineLimit(1 ... 4)
            .textFieldStyle(.roundedBorder)
            .focused($isComposerFocused)

            Button {
                if coachVM.discussingTopic != nil {
                    Task { await coachVM.submitFollowUp(aiService: aiService) }
                } else if !coachVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    coachVM.appendFinalNotes(coachVM.draftText)
                    coachVM.draftText = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(coachVM.isThinking || (coachVM.discussingTopic == nil && coachVM.draftText.isEmpty))
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if coachVM.phase == .review {
                proxy.scrollTo("blueprint-summary", anchor: .bottom)
            } else if coachVM.phase == .recommendations {
                proxy.scrollTo("recommendation-cards", anchor: .bottom)
            } else if let last = coachVM.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CoachConversationView(coachVM: CoachConversationViewModel(builderViewModel: DynamicProgramBuilderViewModel()))
    }
}
