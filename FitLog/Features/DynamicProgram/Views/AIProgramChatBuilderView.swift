//
//  AIProgramChatBuilderView.swift
//  FitLog
//
//  Conversational program builder with inline preview and refinement.
//

import SwiftUI

private enum AIProgramChatLimits {
    static let maxMessageChars = 800
}

struct AIProgramChatMessage: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool
    let text: String
    let showsProgramPreview: Bool

    init(id: UUID = UUID(), isUser: Bool, text: String, showsProgramPreview: Bool = false) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.showsProgramPreview = showsProgramPreview
    }
}

struct AIProgramChatBuilderView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(DataManager.self) private var dataManager
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var messages: [AIProgramChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorBanner: String?
    @State private var navigateToReview = false
    @State private var showPaywall = false
    @FocusState private var isComposerFocused: Bool

    private let starterPrompts = [
        "Build me a 4-day upper/lower hypertrophy program",
        "5-day PPL for strength, 60-minute sessions",
        "Beginner full body 3× per week for 8 weeks",
        "Fat loss program with cardio, 4 days",
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !aiService.isConfigured {
                notConfiguredBanner
            }

            if let errorBanner {
                Text(errorBanner)
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

                        if messages.isEmpty {
                            starterPromptSection
                        }

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Building your program…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }

                        if let program = viewModel.generatedProgram, !isSending {
                            programPreviewCard(program)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            composerBar
        }
        .navigationTitle("AI Builder")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToReview) {
            DynamicProgramBuilderView(viewModel: viewModel)
        }
        .sensoryFeedback(.success, trigger: viewModel.generationSuccessCount)
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .aiProgramGeneration)
                .environment(entitlementStore)
        }
    }

    private var notConfiguredBanner: some View {
        Label("No AI key — programs use local presets. Add a key in Settings for smarter drafts.", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FitlogPalette.subtleFill)
    }

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Describe your ideal program")
                .font(.headline)
            Text("Tell me your goal, days per week, split style, and anything else. I'll draft a program you can refine or open in the full editor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private var starterPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(starterPrompts, id: \.self) { prompt in
                Button(prompt) {
                    draft = prompt
                    Task { await sendMessage() }
                }
                .font(.caption)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                .buttonStyle(.plain)
                .accessibilityHint("Sends this starter prompt to the AI builder")
            }
        }
    }

    private func messageBubble(_ message: AIProgramChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(message.isUser ? Color.accentColor.opacity(0.16) : FitlogPalette.subtleFill)
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.isUser ? "You said \(message.text)" : "Assistant said \(message.text)")
    }

    private func programPreviewCard(_ program: DynamicProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Program draft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(program.name)
                    .font(.headline)
                Text(viewModel.liveSummaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !viewModel.programValidationResult.blockingIssues.isEmpty {
                    Label(viewModel.programValidationResult.blockingIssues.first ?? "Needs attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(FitlogPalette.caution)
                } else {
                    Label("Ready to review", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(FitlogPalette.success)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FitlogPalette.subtleFill)
            )

            HStack(spacing: 10) {
                Button("Open editor") {
                    navigateToReview = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens the full review and edit screen")

                Button("Regenerate") {
                    Task { await regenerateLastRequest() }
                }
                .buttonStyle(.bordered)
                .disabled(isSending)
                .accessibilityHint("Regenerates the program with your latest instructions")
            }
        }
        .padding(.top, 4)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Describe or refine your program…", text: $draft, axis: .vertical)
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
                .accessibilityLabel("Program description")

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
            .accessibilityHint("Generates or refines your program from this message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @MainActor
    private func sendMessage() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= AIProgramChatLimits.maxMessageChars else {
            errorBanner = "Message is too long (max \(AIProgramChatLimits.maxMessageChars) characters)."
            return
        }

        errorBanner = nil
        guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
            showPaywall = true
            return
        }

        isSending = true
        let userMessage = AIProgramChatMessage(isUser: true, text: trimmed)
        messages.append(userMessage)
        draft = ""

        let isRefinement = viewModel.generatedProgram != nil
        if isRefinement {
            viewModel.request.splitInput.adjustmentInstruction = trimmed
        } else {
            viewModel.builderMode = .aiGenerate
            ProgramIntentParser.apply(trimmed, to: &viewModel.request)
            viewModel.applyExperienceBasedDefaults()
            viewModel.applyProgramStructureSelections()
            if viewModel.request.programName == DynamicProgramGenerationRequest.simpleDefault().programName {
                viewModel.request.programName = suggestedProgramName(from: trimmed)
            }
        }

        await viewModel.generate(aiService: aiService, dataManager: dataManager, entitlementStore: entitlementStore)

        if let err = viewModel.errorMessage, !err.isEmpty {
            errorBanner = err
            messages.append(AIProgramChatMessage(isUser: false, text: "I couldn't build that program: \(err)"))
        } else if let program = viewModel.generatedProgram {
            let reply = isRefinement
                ? "Updated your program. \(program.blocks.count) block(s), \(program.defaultSessionsPerWeek) sessions per week."
                : "Here's a draft based on your request. Tap Open editor to customize exercises, or send another message to refine it."
            messages.append(AIProgramChatMessage(isUser: false, text: reply, showsProgramPreview: true))
            viewModel.wizardStep = .reviewAndEdit
        }

        isSending = false
    }

    @MainActor
    private func regenerateLastRequest() async {
        guard viewModel.generatedProgram != nil else { return }
        guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
            showPaywall = true
            return
        }
        isSending = true
        await viewModel.generate(aiService: aiService, dataManager: dataManager, entitlementStore: entitlementStore)
        if let err = viewModel.errorMessage, !err.isEmpty {
            errorBanner = err
        } else {
            messages.append(AIProgramChatMessage(isUser: false, text: "Regenerated your program with the same instructions.", showsProgramPreview: true))
        }
        isSending = false
    }

    private func suggestedProgramName(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("ppl") || lower.contains("push pull") { return "My PPL Program" }
        if lower.contains("upper lower") { return "My Upper/Lower Program" }
        if lower.contains("full body") { return "My Full Body Program" }
        if lower.contains("strength") { return "My Strength Program" }
        if lower.contains("hypertrophy") || lower.contains("muscle") { return "My Hypertrophy Program" }
        return "My AI Program"
    }
}
