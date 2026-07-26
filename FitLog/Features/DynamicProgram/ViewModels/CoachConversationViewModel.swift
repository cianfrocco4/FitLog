//
//  CoachConversationViewModel.swift
//  FitLog
//
//  State machine for the Guided Coach conversational program builder.
//

import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class CoachConversationViewModel {
    private(set) var messages: [CoachMessage] = []
    private(set) var phase: CoachPhase = .intake
    private(set) var intake = CoachIntakeSnapshot()
    private(set) var blueprint: CoachBlueprint?
    private(set) var pendingIntakeTopic: CoachIntakeTopic?
    private(set) var isThinking = false
    private(set) var errorMessage: String?
    private(set) var activeDiscussTopic: CoachRecommendationTopic?
    private(set) var discussThreads: [CoachRecommendationTopic: CoachDiscussThread] = [:]
    private(set) var discussDrafts: [CoachRecommendationTopic: String] = [:]
    private(set) var discussScrollTrigger = 0
    private(set) var scrollToGenerationTrigger = 0
    private(set) var focusedDiscussTopic: CoachRecommendationTopic?
    var draftText = ""
    var scheduleSessions: Int = 3
    var scheduleWeekdays: Set<Int> = []
    var selectionFeedbackCount = 0
    var navigateToReview = false

    let builderViewModel: DynamicProgramBuilderViewModel
    private var intakeQueue: [CoachIntakeTopic] = CoachIntakeTopic.allCases
    private var didBootstrap = false

    init(builderViewModel: DynamicProgramBuilderViewModel) {
        self.builderViewModel = builderViewModel
    }

    // MARK: - Bootstrap

    func bootstrap(dataManager: DataManager) {
        guard !didBootstrap else { return }
        didBootstrap = true
        builderViewModel.bootstrapFromContext(dataManager: dataManager)

        let saved = SplitBuilderPreferencesStore.load()
        if let g = saved.primaryGoalRaw { intake.primaryGoal = g }
        if let g = saved.experienceRaw { intake.experienceLevel = g }
        if let g = saved.equipmentRaw { intake.equipment = g }
        if let n = saved.sessionsPerWeek { intake.sessionsPerWeek = n }
        if let w = saved.selectedWeekdayNumbers { intake.preferredWeekdays = w }
        if let g = saved.splitPreferenceRaw { intake.savedSplitPreference = g }
        if let t = saved.limitationsNotes { intake.limitationsNotes = t }

        let completed = dataManager.completedSessions.filter(\.isCompleted)
        if !completed.isEmpty {
            let cal = Calendar.current
            let cutoff = cal.date(byAdding: .day, value: -28, to: Date()) ?? Date()
            let recent = completed.filter { ($0.endTime ?? Date()) >= cutoff }
            if !recent.isEmpty {
                intake.inferredSessionsPerWeek = max(1, min(7, recent.count / 4))
            }
        }

        scheduleSessions = intake.sessionsPerWeek > 0 ? intake.sessionsPerWeek : (intake.inferredSessionsPerWeek ?? 3)
        scheduleWeekdays = Set(intake.preferredWeekdays.filter { $0 >= 1 && $0 <= 7 })

        appendTrainerMessage(openingMessage())
        askNextIntakeQuestion()
    }

    private func openingMessage() -> String {
        var parts = ["Hey — I'm your program coach. Let's build something that fits your life and goals."]
        if let inferred = intake.inferredSessionsPerWeek {
            parts.append("I can see you've been training about \(inferred) days a week lately — I'll keep that in mind.")
        }
        if let saved = intake.savedSplitPreference, !saved.contains("No preference") {
            parts.append("Last time you preferred \(saved) — we can stick with that or try something new.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Intake flow

    private func askNextIntakeQuestion() {
        guard let topic = intakeQueue.first else {
            transitionToRecommendations()
            return
        }
        pendingIntakeTopic = topic
        let question = intakeQuestion(for: topic)
        appendMessage(CoachMessage(kind: .intakePrompt(topic)))
        appendTrainerMessage(question.prompt)
    }

    func submitQuickReply(_ value: String) {
        guard let topic = pendingIntakeTopic else { return }
        applyIntakeAnswer(topic: topic, value: value)
        appendUserMessage(value)
        selectionFeedbackCount += 1
        acknowledgeIntake(topic: topic, value: value)
        intakeQueue.removeAll { $0 == topic }
        pendingIntakeTopic = nil
        askNextIntakeQuestion()
    }

    func submitScheduleAnswer() {
        guard pendingIntakeTopic == .schedule else { return }
        intake.sessionsPerWeek = min(7, max(1, scheduleSessions))
        intake.preferredWeekdays = scheduleWeekdays.sorted()
        let daySummary = scheduleWeekdays.isEmpty
            ? "\(scheduleSessions) days per week"
            : "\(scheduleSessions) days on selected weekdays"
        applyIntakeAnswer(topic: .schedule, value: daySummary)
        appendUserMessage(daySummary)
        selectionFeedbackCount += 1
        acknowledgeIntake(topic: .schedule, value: daySummary)
        intakeQueue.removeAll { $0 == .schedule }
        pendingIntakeTopic = nil
        askNextIntakeQuestion()
    }

    func submitConstraintsAnswer() {
        guard pendingIntakeTopic == .constraints else { return }
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "None" : trimmed
        intake.limitationsNotes = value == "None" ? "" : String(trimmed.prefix(400))
        applyIntakeAnswer(topic: .constraints, value: value)
        appendUserMessage(value)
        draftText = ""
        selectionFeedbackCount += 1
        if !intake.limitationsNotes.isEmpty {
            appendTrainerMessage("Thanks for sharing — I'll keep that in mind and stay conservative where it matters. If anything feels painful, please check with a qualified clinician.")
        } else {
            acknowledgeIntake(topic: .constraints, value: value)
        }
        intakeQueue.removeAll { $0 == .constraints }
        pendingIntakeTopic = nil
        askNextIntakeQuestion()
    }

    private func applyIntakeAnswer(topic: CoachIntakeTopic, value: String) {
        switch topic {
        case .goal:
            intake.primaryGoal = value
        case .experience:
            intake.experienceLevel = value
        case .schedule:
            break // handled in submitScheduleAnswer
        case .equipment:
            intake.equipment = value
        case .constraints:
            break // handled in submitConstraintsAnswer
        }
    }

    private func acknowledgeIntake(topic: CoachIntakeTopic, value: String) {
        switch topic {
        case .goal:
            appendTrainerMessage("Got it — \(value.lowercased()) is a clear direction. Let's shape the program around that.")
        case .experience:
            appendTrainerMessage("\(value) — perfect. I'll match the complexity to where you're at.")
        case .schedule:
            appendTrainerMessage("\(value.capitalized) — that gives us a solid foundation to work with.")
        case .equipment:
            appendTrainerMessage("\(value) — I'll pick exercises that fit what you have.")
        case .constraints:
            appendTrainerMessage("Noted. We'll build around that.")
        }
    }

    private func intakeQuestion(for topic: CoachIntakeTopic) -> CoachQuestion {
        switch topic {
        case .goal:
            return CoachQuestion(
                topic: topic,
                prompt: "What's the main thing you want to get out of this program?",
                responseKind: .quickReplies,
                quickReplies: CoachGoalPick.allCases.map(\.rawValue)
            )
        case .experience:
            return CoachQuestion(
                topic: topic,
                prompt: "How long have you been training consistently?",
                responseKind: .quickReplies,
                quickReplies: CoachExperiencePick.allCases.map(\.rawValue)
            )
        case .schedule:
            return CoachQuestion(
                topic: topic,
                prompt: "How many days a week can you realistically train? Pick preferred days if you have them.",
                responseKind: .schedule
            )
        case .equipment:
            return CoachQuestion(
                topic: topic,
                prompt: "What equipment do you have access to?",
                responseKind: .quickReplies,
                quickReplies: CoachEquipmentPick.allCases.map(\.rawValue)
            )
        case .constraints:
            return CoachQuestion(
                topic: topic,
                prompt: "Any injuries, limitations, or things I should know about?",
                responseKind: .textOptional,
                quickReplies: ["None"]
            )
        }
    }

    func quickRepliesForPendingQuestion() -> [String] {
        guard let topic = pendingIntakeTopic else { return [] }
        return intakeQuestion(for: topic).quickReplies
    }

    // MARK: - Recommendations

    private func transitionToRecommendations() {
        phase = .recommendations
        appendMessage(CoachMessage(kind: .phaseDivider("Now let me put together your plan…")))
        var built = CoachRecommendationEngine.buildBlueprint(from: intake)
        blueprint = built
        appendTrainerMessage("Based on everything you've told me, here's what I'd recommend. You can accept each part, adjust it, or ask me why.")
        appendMessage(CoachMessage(kind: .recommendationCards))
        for warning in built.warnings {
            appendTrainerMessage("Heads up: \(warning)")
        }
    }

    func enrichRecommendationsWithAI(aiService: AIService) async {
        guard var built = blueprint else { return }
        isThinking = true
        appendTypingIndicator()
        defer {
            removeTypingIndicator()
            isThinking = false
        }

        if let explanation = await aiService.explainCoachRecommendations(blueprint: built, intake: intake) {
            if !explanation.summary.isEmpty {
                appendTrainerMessage(explanation.summary)
            }
            for item in explanation.recommendations {
                guard let topic = item.resolvedTopic,
                      let index = built.recommendations.firstIndex(where: { $0.topic == topic }) else { continue }
                if !item.rationale.isEmpty {
                    built.recommendations[index].rationale = item.rationale
                }
            }
            for warning in explanation.warnings where !built.warnings.contains(warning) {
                built.warnings.append(warning)
                appendTrainerMessage("Heads up: \(warning)")
            }
            blueprint = built
            refreshRecommendationMessages()
        }
    }

    private func refreshRecommendationMessages() {
        messages.removeAll { msg in
            if case .recommendationCards = msg.kind { return true }
            return false
        }
        if let idx = messages.lastIndex(where: { if case .phaseDivider = $0.kind { return true }; return false }) {
            messages.insert(CoachMessage(kind: .recommendationCards), at: idx + 1)
        } else {
            appendMessage(CoachMessage(kind: .recommendationCards))
        }
    }

    func acceptRecommendation(_ topic: CoachRecommendationTopic) {
        guard var built = blueprint,
              let index = built.recommendations.firstIndex(where: { $0.topic == topic }) else { return }
        built.recommendations[index].isAccepted = true
        blueprint = built
        selectionFeedbackCount += 1
        if allRecommendationsAccepted {
            transitionToReview()
        }
    }

    func acceptAllRecommendations() {
        guard var built = blueprint else { return }
        for index in built.recommendations.indices {
            built.recommendations[index].isAccepted = true
        }
        blueprint = built
        selectionFeedbackCount += 1
        transitionToReview()
    }

    func applyRecommendationOverride(topic: CoachRecommendationTopic, newValue: String, acceptAfterApply: Bool = true) {
        guard var built = blueprint else { return }
        if let change = CoachRecommendationEngine.applyRecommendationChange(to: &built, topic: topic, newValue: newValue) {
            blueprint = built
            appendMessage(CoachMessage(kind: .changeSummary([change])))
            appendTrainerMessage("Updated — \(change.diffDescription).")
        }
        if acceptAfterApply {
            acceptRecommendation(topic)
        }
    }

    var allRecommendationsAccepted: Bool {
        guard let built = blueprint else { return false }
        return built.recommendations.allSatisfy(\.isAccepted)
    }

    // MARK: - Discuss (per-topic threads)

    func thread(for topic: CoachRecommendationTopic) -> CoachDiscussThread? {
        discussThreads[topic]
    }

    func draft(for topic: CoachRecommendationTopic) -> Binding<String> {
        Binding(
            get: { self.discussDrafts[topic] ?? "" },
            set: { self.discussDrafts[topic] = $0 }
        )
    }

    func isDiscussing(_ topic: CoachRecommendationTopic) -> Bool {
        activeDiscussTopic == topic
    }

    func beginDiscuss(topic: CoachRecommendationTopic) {
        activeDiscussTopic = topic
        focusedDiscussTopic = topic
        bumpDiscussScrollTrigger()

        var thread = discussThreads[topic] ?? CoachDiscussThread(topic: topic)
        if thread.messages.isEmpty {
            let seed = "Ask me anything about \(topic.title.lowercased()) — happy to explain the tradeoffs."
            thread.messages.append(CoachDiscussMessage(role: .coach, kind: .text(seed)))
            thread.lastUpdatedAt = Date()
        }
        discussThreads[topic] = thread
    }

    func endDiscuss(topic: CoachRecommendationTopic) {
        guard activeDiscussTopic == topic else { return }
        activeDiscussTopic = nil
        focusedDiscussTopic = nil
        bumpDiscussScrollTrigger()
    }

    func submitFollowUp(for topic: CoachRecommendationTopic, aiService: AIService) async {
        let question = (discussDrafts[topic] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, let built = blueprint else { return }

        appendDiscussMessage(topic: topic, role: .user, kind: .text(question))
        discussDrafts[topic] = ""
        setDiscussThinking(topic: topic, isThinking: true)
        appendDiscussTyping(topic: topic)
        bumpDiscussScrollTrigger()

        if let response = await aiService.respondToCoachFollowUp(
            blueprint: built,
            intake: intake,
            question: question,
            topic: topic
        ) {
            removeDiscussTyping(topic: topic)
            appendDiscussMessage(topic: topic, role: .coach, kind: .text(response.answer))

            let validSuggestions = response.suggestedChanges.filter { suggestion in
                guard let resolved = suggestion.resolvedTopic else { return false }
                return resolved == topic
            }
            if !validSuggestions.isEmpty {
                appendDiscussMessage(topic: topic, role: .coach, kind: .suggestions(validSuggestions))
                var thread = discussThreads[topic] ?? CoachDiscussThread(topic: topic)
                thread.pendingSuggestions = validSuggestions
                discussThreads[topic] = thread
            }
        } else {
            removeDiscussTyping(topic: topic)
            let fallback = localFollowUpAnswer(for: question, topic: topic)
            appendDiscussMessage(topic: topic, role: .coach, kind: .text(fallback))
        }

        setDiscussThinking(topic: topic, isThinking: false)
        bumpDiscussScrollTrigger()
    }

    func applySuggestedChange(_ change: CoachFollowUpSuggestedChange, in topic: CoachRecommendationTopic) {
        guard change.resolvedTopic == topic else { return }
        applyRecommendationOverride(topic: topic, newValue: change.suggestedValue, acceptAfterApply: false)

        var thread = discussThreads[topic] ?? CoachDiscussThread(topic: topic)
        thread.pendingSuggestions.removeAll { $0.topic == change.topic }
        let appliedText = "Applied: \(topic.title) updated to \(change.suggestedValue)."
        thread.messages.append(CoachDiscussMessage(role: .system, kind: .text(appliedText)))
        thread.lastUpdatedAt = Date()
        discussThreads[topic] = thread
        bumpDiscussScrollTrigger()
    }

    private func appendDiscussMessage(topic: CoachRecommendationTopic, role: CoachDiscussMessageRole, kind: CoachDiscussMessageKind) {
        var thread = discussThreads[topic] ?? CoachDiscussThread(topic: topic)
        thread.messages.append(CoachDiscussMessage(role: role, kind: kind))
        thread.lastUpdatedAt = Date()
        discussThreads[topic] = thread
    }

    private func appendDiscussTyping(topic: CoachRecommendationTopic) {
        var thread = discussThreads[topic] ?? CoachDiscussThread(topic: topic)
        thread.messages.removeAll { if case .typing = $0.kind { return true }; return false }
        thread.messages.append(CoachDiscussMessage(role: .coach, kind: .typing))
        thread.isThinking = true
        discussThreads[topic] = thread
    }

    private func removeDiscussTyping(topic: CoachRecommendationTopic) {
        guard var thread = discussThreads[topic] else { return }
        thread.messages.removeAll { if case .typing = $0.kind { return true }; return false }
        thread.isThinking = false
        discussThreads[topic] = thread
    }

    private func setDiscussThinking(topic: CoachRecommendationTopic, isThinking: Bool) {
        guard var thread = discussThreads[topic] else { return }
        thread.isThinking = isThinking
        discussThreads[topic] = thread
    }

    private func bumpDiscussScrollTrigger() {
        discussScrollTrigger += 1
    }

    private func localFollowUpAnswer(for question: String, topic: CoachRecommendationTopic?) -> String {
        let lower = question.lowercased()
        if lower.contains("why") && topic == .cardio {
            return "I'm keeping cardio manageable so it supports your goal without eating into recovery from lifting."
        }
        if lower.contains("ppl") || lower.contains("push") {
            return "Push/Pull/Legs works great when you can train often enough to hit each pattern twice per week. With fewer days, Upper/Lower or Full Body usually fits better."
        }
        return "Good question. You can adjust any recommendation above — your final choices are what we'll build from."
    }

    // MARK: - Review & generate

    private func transitionToReview() {
        activeDiscussTopic = nil
        focusedDiscussTopic = nil
        phase = .review
        appendMessage(CoachMessage(kind: .phaseDivider("Here's your program blueprint")))
        appendTrainerMessage("Here's what I recommend. You can change anything before I build it — you're in control.")
        appendMessage(CoachMessage(kind: .blueprintSummary))
    }

    func applyBlueprintToBuilder() {
        guard let built = blueprint else { return }
        let request = built.toGenerationRequest()
        builderViewModel.request = request
        builderViewModel.programStructurePreset = built.isPeriodized
            ? (built.blockSpecs.count >= 3 ? .threePhases : .twoPhases)
            : .singlePhase
        builderViewModel.totalWeeksTemplate = DynamicProgramBuilderViewModel.TotalWeeksTemplate(rawValue: built.totalWeeks) ?? .custom
        builderViewModel.customTotalProgramWeeks = built.totalWeeks
        builderViewModel.builderMode = .aiGenerate
        builderViewModel.wizardStep = .reviewAndEdit
        builderViewModel.persistPreferencesToStore()
    }

    func buildProgram(aiService: AIService, dataManager: DataManager, entitlementStore: EntitlementStore) async {
        guard entitlementStore.hasAccess(to: .aiProgramGeneration) else { return }
        phase = .generating
        applyBlueprintToBuilder()
        appendTrainerMessage("Building your program now…")
        appendTypingIndicator()
        scrollToGenerationTrigger += 1
        await builderViewModel.generate(aiService: aiService, dataManager: dataManager, entitlementStore: entitlementStore)
        removeTypingIndicator()
        if builderViewModel.generatedProgram != nil {
            phase = .complete
            navigateToReview = true
        } else {
            phase = .review
            errorMessage = builderViewModel.errorMessage ?? "Could not build the program."
            appendTrainerMessage(errorMessage ?? "Something went wrong. You can try again or use built-in presets from the editor.")
        }
    }

    var generationStatusLine: String {
        builderViewModel.generationStatusMessage ?? "Building your program…"
    }

    func appendFinalNotes(_ notes: String) {
        intake.additionalNotes = String(notes.prefix(400))
    }

    private func appendTrainerMessage(_ text: String) {
        appendMessage(CoachMessage(kind: .trainerText(text)))
    }

    private func appendUserMessage(_ text: String) {
        appendMessage(CoachMessage(kind: .userReply(text)))
    }

    private func appendMessage(_ message: CoachMessage) {
        messages.append(message)
    }

    private func appendTypingIndicator() {
        guard !messages.contains(where: { if case .typingIndicator = $0.kind { return true }; return false }) else { return }
        appendMessage(CoachMessage(kind: .typingIndicator))
    }

    private func removeTypingIndicator() {
        messages.removeAll { if case .typingIndicator = $0.kind { return true }; return false }
    }
}
