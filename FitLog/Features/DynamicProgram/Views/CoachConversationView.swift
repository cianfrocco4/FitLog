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
    @State private var showPaywall = false
    @State private var paywallTrigger: PremiumFeature = .aiCoach
    @State private var hoveredGoalTeaser: String?
    @FocusState private var isIntakeNotesFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if coachVM.phase == .planPreview || coachVM.phase == .generating {
                planPreviewSurface
            } else {
                intakeChatSurface
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
            if coachVM.phase == .planPreview, coachVM.blueprint != nil, entitlementStore.hasAccess(to: .aiCoach) {
                await coachVM.enrichRecommendationsWithAI(aiService: aiService)
            }
        }
        .sheet(isPresented: Binding(
            get: { coachVM.activeDiscussTopic != nil },
            set: { if !$0, let topic = coachVM.activeDiscussTopic { coachVM.endDiscuss(topic: topic) } }
        )) {
            if let topic = coachVM.activeDiscussTopic {
                discussSheet(for: topic)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                triggerFeature: paywallTrigger,
                analyticsSource: paywallTrigger == .aiProgramGeneration
                    ? "coach_program_generation"
                    : "coach_conversation"
            )
                .environment(entitlementStore)
        }
        .sensoryFeedback(.selection, trigger: coachVM.selectionFeedbackCount)
        .sensoryFeedback(.success, trigger: coachVM.builderViewModel.generationSuccessCount)
    }

    // MARK: - Intake chat

    private var intakeChatSurface: some View {
        VStack(spacing: 0) {
            if coachVM.phase == .intake {
                intakeProgressBar
            }

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
                        if !coachVM.answeredTopics.isEmpty {
                            answeredChips
                        }

                        ForEach(coachVM.messages) { message in
                            messageView(for: message)
                                .id(message.id)
                        }

                        if let topic = coachVM.pendingIntakeTopic {
                            intakeInput(for: topic)
                                .id("intake-input")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .keyboardDismissToolbar()
                .onChange(of: coachVM.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.22)) {
                        if let last = coachVM.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        } else {
                            proxy.scrollTo("intake-input", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isIntakeNotesFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("intake-input", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var intakeProgressBar: some View {
        HStack {
            Text("Step \(min(coachVM.intakeStepIndex, coachVM.intakeStepTotal)) of \(coachVM.intakeStepTotal)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView(value: Double(coachVM.intakeStepIndex), total: Double(max(1, coachVM.intakeStepTotal)))
                .frame(width: 120)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Intake progress, step \(coachVM.intakeStepIndex) of \(coachVM.intakeStepTotal)")
    }

    private var answeredChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(coachVM.answeredTopics, id: \.self) { topic in
                    if let value = coachVM.answeredValue(for: topic) {
                        Button {
                            coachVM.revisitIntakeTopic(topic)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topicChipTitle(topic))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(value)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(FitlogPalette.subtleFill)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(topicChipTitle(topic)): \(value)")
                        .accessibilityHint("Go back and change this answer")
                    }
                }
            }
        }
    }

    private func topicChipTitle(_ topic: CoachIntakeTopic) -> String {
        switch topic {
        case .goal: return "Goal"
        case .goalFollowUp: return "Focus"
        case .experience: return "Experience"
        case .schedule: return "Schedule"
        case .sessionDuration: return "Session length"
        case .equipment: return "Equipment"
        case .constraints: return "Notes"
        }
    }

    // MARK: - Plan preview surface

    private var planPreviewSurface: some View {
        VStack(spacing: 0) {
            if let error = coachVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
            }

            if coachVM.phase == .generating, let blueprint = coachVM.blueprint {
                ScrollView {
                    CoachProgramGenerationProgressView(
                        statusMessage: coachVM.generationStatusLine,
                        stage: coachVM.builderViewModel.generationStage,
                        blockCompleted: coachVM.builderViewModel.generationBlockCompleted,
                        blockTotal: coachVM.builderViewModel.generationBlockTotal,
                        programTitle: blueprint.programName,
                        daysPerWeek: blueprint.sessionsPerWeek
                    )
                    .padding(16)
                }
            } else if let blueprint = coachVM.blueprint {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        DisclosureGroup(isExpanded: $coachVM.showCoachNotes) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(coachVM.messages.filter { msg in
                                    switch msg.kind {
                                    case .trainerText, .userReply, .phaseDivider, .changeSummary:
                                        return true
                                    default:
                                        return false
                                    }
                                }) { message in
                                    messageView(for: message)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("Coach notes")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 4)

                        CoachPlanPreviewView(
                            blueprint: blueprint,
                            scheduleSessions: $coachVM.scheduleSessions,
                            weekdays: $coachVM.scheduleWeekdays,
                            finalNotes: $coachVM.finalNotesDraft,
                            autoUpdates: coachVM.lastAutoUpdates,
                            isLoading: coachVM.phase == .generating,
                            requiresPremium: !entitlementStore.hasAccess(to: .aiProgramGeneration),
                            onUpdateRecommendation: { topic, value in
                                coachVM.updateRecommendation(topic: topic, newValue: value)
                            },
                            onUpdateSchedule: { sessions, days in
                                coachVM.updateSchedule(sessions: sessions, weekdays: days)
                            },
                            onDiscuss: { topic in
                                coachVM.beginDiscuss(topic: topic)
                            },
                            onBuild: {
                                guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
                                    paywallTrigger = .aiProgramGeneration
                                    showPaywall = true
                                    return
                                }
                                Task {
                                    await coachVM.buildProgram(
                                        aiService: aiService,
                                        dataManager: dataManager,
                                        entitlementStore: entitlementStore,
                                        reduceMotion: reduceMotion
                                    )
                                }
                            }
                        )
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .keyboardDismissToolbar()
            }
        }
    }

    // MARK: - Discuss sheet

    @ViewBuilder
    private func discussSheet(for topic: CoachRecommendationTopic) -> some View {
        NavigationStack {
            Group {
                if let thread = coachVM.thread(for: topic) {
                    CoachInlineDiscussThread(
                        topic: topic,
                        thread: thread,
                        draftText: coachVM.draft(for: topic),
                        isActive: true,
                        shouldFocusComposer: coachVM.focusedDiscussTopic == topic,
                        onSend: {
                            guard entitlementStore.hasAccess(to: .aiCoach) else {
                                paywallTrigger = .aiCoach
                                showPaywall = true
                                return
                            }
                            Task { await coachVM.submitFollowUp(for: topic, aiService: aiService) }
                        },
                        onApplySuggestion: { change in
                            coachVM.applySuggestedChange(change, in: topic)
                        },
                        onDone: { coachVM.endDiscuss(topic: topic) },
                        onReopenDiscuss: { coachVM.beginDiscuss(topic: topic) }
                    )
                    .padding()
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Discuss \(topic.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { coachVM.endDiscuss(topic: topic) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Shared message / intake helpers

    @ViewBuilder
    private func messageView(for message: CoachMessage) -> some View {
        switch message.kind {
        case .planPreview, .intakePrompt:
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
                    isIntakeNotesFocused = false
                    fitlogDismissKeyboard()
                    coachVM.draftText = value
                    coachVM.submitConstraintsAnswer()
                }
                TextField("Optional details", text: $coachVM.draftText, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.roundedBorder)
                    .focused($isIntakeNotesFocused)
                    .accessibilityLabel("Optional constraint details")
                    .accessibilityHint("Add injuries, preferences, or other notes. Tap Done to dismiss the keyboard.")
                Button("Continue") {
                    isIntakeNotesFocused = false
                    fitlogDismissKeyboard()
                    coachVM.submitConstraintsAnswer()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Continue")
                .accessibilityHint("Save notes and continue to the next question")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FitlogPalette.subtleFill)
            )
        case .goal:
            VStack(alignment: .leading, spacing: 10) {
                CoachQuickReplyPills(options: coachVM.quickRepliesForPendingQuestion()) { value in
                    hoveredGoalTeaser = coachVM.goalImpactTeaser(for: value)
                    coachVM.submitQuickReply(value)
                }
                Text(hoveredGoalTeaser ?? "Your goal shapes program length, intensity, phases, and cardio — not just the title.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(hoveredGoalTeaser ?? "Your goal shapes program length, intensity, phases, and cardio")
            }
        default:
            CoachQuickReplyPills(options: coachVM.quickRepliesForPendingQuestion()) { value in
                coachVM.submitQuickReply(value)
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
