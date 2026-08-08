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
    private(set) var lastAutoUpdates: [CoachRecommendationChange] = []
    private(set) var answeredTopics: [CoachIntakeTopic] = []
    var draftText = ""
    var finalNotesDraft = ""
    var scheduleSessions: Int = 3
    var scheduleWeekdays: Set<Int> = []
    var selectionFeedbackCount = 0
    var navigateToReview = false
    var showCoachNotes = false

    let builderViewModel: DynamicProgramBuilderViewModel
    private var intakeQueue: [CoachIntakeTopic] = CoachIntakeTopic.standardIntakeOrder
    private var didBootstrap = false
    private var answeredValues: [CoachIntakeTopic: String] = [:]

    init(builderViewModel: DynamicProgramBuilderViewModel) {
        self.builderViewModel = builderViewModel
    }

    // MARK: - Progress

    var intakeStepIndex: Int {
        guard let pending = pendingIntakeTopic else {
            return max(1, answeredTopics.count)
        }
        let visible = CoachIntakeTopic.standardIntakeOrder + (answeredTopics.contains(.goalFollowUp) || pending == .goalFollowUp ? [.goalFollowUp] : [])
        if let idx = visible.firstIndex(of: pending) {
            return idx + 1
        }
        return answeredTopics.count + 1
    }

    var intakeStepTotal: Int {
        var total = CoachIntakeTopic.standardIntakeOrder.count
        if answeredTopics.contains(.goalFollowUp) || pendingIntakeTopic == .goalFollowUp || shouldOfferGoalFollowUp {
            total += 1
        }
        return total
    }

    private var shouldOfferGoalFollowUp: Bool {
        let programming = CoachGoalProgramming.resolve(from: intake.primaryGoal, experienceLevel: intake.experienceLevel)
        switch programming.goal {
        case .performance, .strength, .fatLoss:
            return true
        case .buildMuscle, .general:
            return false
        }
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
        if let durationRaw = saved.sessionDurationRaw {
            intake.sessionDurationMinutes = SessionDurationBuckets.minutes(fromPickerLabel: durationRaw)
        }
        if let priority = saved.priorityMusclesOrLiftsNotes {
            intake.priorityMusclesOrLiftsNotes = String(priority.prefix(400))
        }

        let completed = dataManager.completedSessions.filter(\.isCompleted)
        if !completed.isEmpty {
            let cal = Calendar.current
            let cutoff = cal.date(byAdding: .day, value: -28, to: Date()) ?? Date()
            let recent = completed.filter { ($0.endTime ?? Date()) >= cutoff }
            if !recent.isEmpty {
                intake.inferredSessionsPerWeek = max(1, min(7, recent.count / 4))
            }
        }

        scheduleWeekdays = Set(intake.preferredWeekdays.filter { $0 >= 1 && $0 <= 7 })
        let rawSessions = intake.sessionsPerWeek > 0 ? intake.sessionsPerWeek : (intake.inferredSessionsPerWeek ?? 3)
        let reconciled = CoachScheduleSync.reconcile(sessions: rawSessions, weekdays: Array(scheduleWeekdays))
        scheduleSessions = reconciled.sessions
        scheduleWeekdays = Set(reconciled.weekdays)
        intake.sessionsPerWeek = reconciled.sessions
        intake.preferredWeekdays = reconciled.weekdays

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
            transitionToPlanPreview()
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
        markAnswered(topic: topic, value: value)
        advancePast(topic)
    }

    func submitScheduleAnswer() {
        guard pendingIntakeTopic == .schedule else { return }
        let reconciled = CoachScheduleSync.reconcile(sessions: scheduleSessions, weekdays: Array(scheduleWeekdays))
        scheduleSessions = reconciled.sessions
        scheduleWeekdays = Set(reconciled.weekdays)
        intake.sessionsPerWeek = reconciled.sessions
        intake.preferredWeekdays = reconciled.weekdays
        let daySummary = reconciled.weekdays.isEmpty
            ? "\(reconciled.sessions) days per week"
            : "\(reconciled.sessions) sessions on \(reconciled.weekdays.count) preferred day\(reconciled.weekdays.count == 1 ? "" : "s")"
        applyIntakeAnswer(topic: .schedule, value: daySummary)
        appendUserMessage(daySummary)
        selectionFeedbackCount += 1
        acknowledgeIntake(topic: .schedule, value: daySummary)
        markAnswered(topic: .schedule, value: daySummary)
        advancePast(.schedule)
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
        markAnswered(topic: .constraints, value: value)
        advancePast(.constraints)
    }

    func revisitIntakeTopic(_ topic: CoachIntakeTopic) {
        guard phase == .intake else { return }
        // Drop later answers so the queue restarts from this topic.
        if let idx = answeredTopics.firstIndex(of: topic) {
            let dropped = answeredTopics[idx...]
            for t in dropped {
                answeredValues[t] = nil
            }
            answeredTopics.removeSubrange(idx...)
        }
        intakeQueue = remainingQueue(startingAt: topic)
        pendingIntakeTopic = nil
        askNextIntakeQuestion()
    }

    private func remainingQueue(startingAt topic: CoachIntakeTopic) -> [CoachIntakeTopic] {
        var order = CoachIntakeTopic.standardIntakeOrder
        if shouldOfferGoalFollowUp, let goalIdx = order.firstIndex(of: .goal) {
            order.insert(.goalFollowUp, at: goalIdx + 1)
        }
        guard let start = order.firstIndex(of: topic) else { return order }
        return Array(order[start...])
    }

    private func advancePast(_ topic: CoachIntakeTopic) {
        intakeQueue.removeAll { $0 == topic }
        if topic == .goal, shouldOfferGoalFollowUp, !intakeQueue.contains(.goalFollowUp), !answeredTopics.contains(.goalFollowUp) {
            intakeQueue.insert(.goalFollowUp, at: 0)
        }
        pendingIntakeTopic = nil
        askNextIntakeQuestion()
    }

    private func markAnswered(topic: CoachIntakeTopic, value: String) {
        answeredValues[topic] = value
        answeredTopics.removeAll { $0 == topic }
        answeredTopics.append(topic)
    }

    func answeredValue(for topic: CoachIntakeTopic) -> String? {
        answeredValues[topic]
    }

    private func applyIntakeAnswer(topic: CoachIntakeTopic, value: String) {
        switch topic {
        case .goal:
            intake.primaryGoal = value
        case .goalFollowUp:
            applyGoalFollowUp(value)
        case .experience:
            intake.experienceLevel = value
        case .schedule:
            break
        case .sessionDuration:
            intake.sessionDurationMinutes = SessionDurationBuckets.minutes(fromPickerLabel: value)
        case .equipment:
            intake.equipment = value
        case .constraints:
            break
        }
    }

    private func applyGoalFollowUp(_ value: String) {
        let programming = CoachGoalProgramming.resolve(from: intake.primaryGoal, experienceLevel: intake.experienceLevel)
        let lower = value.lowercased()
        if lower.contains("skip") {
            return
        }
        if programming.goal == .fatLoss {
            // Encode cardio appetite into additional notes + priority so generation sees it.
            // Engine cardio still comes from goal; this nudges the AI via notes.
            let note: String
            if lower.contains("mixed") {
                note = "Prefer mixed cardio (dedicated days + finishers)."
            } else if lower.contains("dedicated") {
                note = "Prefer dedicated cardio days alongside lifting."
            } else if lower.contains("finisher") || lower.contains("light") {
                note = "Prefer light post-lift finishers only."
            } else {
                note = value
            }
            intake.priorityMusclesOrLiftsNotes = note
            if intake.additionalNotes.isEmpty {
                intake.additionalNotes = note
            } else if !intake.additionalNotes.contains(note) {
                intake.additionalNotes += "\n\(note)"
            }
            return
        }
        intake.priorityMusclesOrLiftsNotes = String(value.prefix(400))
    }

    private func acknowledgeIntake(topic: CoachIntakeTopic, value: String) {
        switch topic {
        case .goal:
            let teaser = CoachGoalProgramming.resolve(from: value, experienceLevel: intake.experienceLevel).impactTeaser
            appendTrainerMessage("Got it — \(value.lowercased()) is a clear direction. \(teaser)")
        case .goalFollowUp:
            appendTrainerMessage("Noted — I'll prioritize that when I build your sessions.")
        case .experience:
            appendTrainerMessage("\(value) — perfect. I'll match the complexity to where you're at.")
        case .schedule:
            appendTrainerMessage("\(value.capitalized) — that gives us a solid foundation to work with.")
        case .sessionDuration:
            appendTrainerMessage("\(value) — I'll size volume so sessions fit.")
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
        case .goalFollowUp:
            return goalFollowUpQuestion()
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
        case .sessionDuration:
            return CoachQuestion(
                topic: topic,
                prompt: "How long is a typical training session?",
                responseKind: .quickReplies,
                quickReplies: CoachSessionDurationPick.allCases.map(\.rawValue)
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

    private func goalFollowUpQuestion() -> CoachQuestion {
        let programming = CoachGoalProgramming.resolve(from: intake.primaryGoal, experienceLevel: intake.experienceLevel)
        switch programming.goal {
        case .performance:
            return CoachQuestion(
                topic: .goalFollowUp,
                prompt: "Any sport or priority lifts I should emphasize?",
                responseKind: .quickReplies,
                quickReplies: [
                    "General athleticism",
                    "Sprinting / field sports",
                    "Olympic lifting focus",
                    "Skip — no specific focus",
                ]
            )
        case .strength:
            return CoachQuestion(
                topic: .goalFollowUp,
                prompt: "Any priority lifts to emphasize?",
                responseKind: .quickReplies,
                quickReplies: [
                    "Squat focus",
                    "Bench focus",
                    "Deadlift focus",
                    "All big three",
                    "Skip — no specific focus",
                ]
            )
        case .fatLoss:
            return CoachQuestion(
                topic: .goalFollowUp,
                prompt: "How much cardio do you want alongside lifting?",
                responseKind: .quickReplies,
                quickReplies: [
                    "Light finishers only",
                    "A couple dedicated cardio days",
                    "Mixed — finishers + dedicated days",
                    "Skip — use your best judgment",
                ]
            )
        default:
            return CoachQuestion(
                topic: .goalFollowUp,
                prompt: "Anything else to prioritize?",
                responseKind: .quickReplies,
                quickReplies: ["Skip — no specific focus"]
            )
        }
    }

    func quickRepliesForPendingQuestion() -> [String] {
        guard let topic = pendingIntakeTopic else { return [] }
        return intakeQuestion(for: topic).quickReplies
    }

    func goalImpactTeaser(for goalRaw: String) -> String {
        CoachGoalProgramming.resolve(from: goalRaw, experienceLevel: intake.experienceLevel).impactTeaser
    }

    // MARK: - Plan preview

    private func transitionToPlanPreview() {
        phase = .planPreview
        appendMessage(CoachMessage(kind: .phaseDivider("Your editable program plan")))
        let built = CoachRecommendationEngine.buildBlueprint(from: intake)
        blueprint = built
        scheduleSessions = built.sessionsPerWeek
        scheduleWeekdays = Set(built.preferredWeekdays)
        appendTrainerMessage(planPreviewSummaryMessage(for: built))
        appendMessage(CoachMessage(kind: .planPreview))
        for warning in built.warnings {
            appendTrainerMessage("Heads up: \(warning)")
        }
    }

    private func planPreviewSummaryMessage(for built: CoachBlueprint) -> String {
        let duration = SessionDurationBuckets.pickerLabel(fromMinutes: built.sessionDurationMinutes)
        let durationBit = built.sessionDurationMinutes == nil ? "" : ", \(duration.replacingOccurrences(of: "~", with: "").replacingOccurrences(of: " per session", with: ""))"
        return "Because you chose \(built.primaryGoal.lowercased()), \(built.sessionsPerWeek) days/week, \(built.equipment.lowercased())\(durationBit) → \(built.splitPreference) with \(cardioShort(built)). Edit anything below, then build when you're ready."
    }

    private func cardioShort(_ built: CoachBlueprint) -> String {
        if built.cardioConfiguration.preference == .none { return "strength-only focus" }
        return built.cardioConfiguration.preference.rawValue.lowercased()
    }

    func enrichRecommendationsWithAI(aiService: AIService) async {
        guard var built = blueprint, phase == .planPreview else { return }
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
            }
            blueprint = built
        }
    }

    func updateRecommendation(topic: CoachRecommendationTopic, newValue: String) {
        guard var built = blueprint else { return }
        if CoachRecommendationEngine.applyRecommendationChange(to: &built, topic: topic, newValue: newValue) != nil {
            CoachRecommendationEngine.recomputeWarnings(blueprint: &built, intake: intake)
            blueprint = built
            selectionFeedbackCount += 1
            lastAutoUpdates = []
            // Changes are visible on the Plan Preview surface; skip chat spam.
        } else {
            CoachRecommendationEngine.recomputeWarnings(blueprint: &built, intake: intake)
            blueprint = built
        }
    }

    func updateProgramName(_ name: String) {
        let trimmed = String(name.prefix(80))
        guard !trimmed.isEmpty else { return }
        updateRecommendation(topic: .programName, newValue: trimmed)
    }

    func updateSchedule(sessions: Int, weekdays: Set<Int>) {
        guard var built = blueprint else { return }
        CoachRecommendationEngine.applyScheduleChange(
            to: &built,
            sessions: sessions,
            weekdays: Array(weekdays)
        )
        scheduleSessions = built.sessionsPerWeek
        scheduleWeekdays = Set(built.preferredWeekdays)
        intake.sessionsPerWeek = built.sessionsPerWeek
        intake.preferredWeekdays = built.preferredWeekdays
        blueprint = built

        let updates = CoachRecommendationEngine.rederive(blueprint: &built, intake: intake)
        blueprint = built
        lastAutoUpdates = updates
        selectionFeedbackCount += 1
        if !updates.isEmpty {
            appendMessage(CoachMessage(kind: .changeSummary(updates)))
            let summary = updates.map { "\($0.topic.title) → \($0.afterValue)" }.joined(separator: "; ")
            appendTrainerMessage("Updated for your new schedule: \(summary).")
        }
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
        updateRecommendation(topic: topic, newValue: change.suggestedValue)

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
        return "Good question. You can edit any field in the plan preview — your final choices are what we'll build from."
    }

    // MARK: - Generate

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
        // Flush any unsubmitted final notes before generating.
        if !finalNotesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendFinalNotes(finalNotesDraft)
            finalNotesDraft = ""
        }
        phase = .generating
        errorMessage = nil
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
            phase = .planPreview
            errorMessage = builderViewModel.errorMessage ?? "Could not build the program."
            appendTrainerMessage(errorMessage ?? "Something went wrong. You can try again or use built-in presets from the editor.")
        }
    }

    var generationStatusLine: String {
        builderViewModel.generationStatusMessage ?? "Building your program…"
    }

    func appendFinalNotes(_ notes: String) {
        let trimmed = String(notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
        intake.additionalNotes = trimmed
        if var built = blueprint {
            built.additionalNotes = trimmed
            blueprint = built
        }
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
