//
//  CoachRecommendationEngine.swift
//  FitLog
//
//  Deterministic local recommendations for the Guided Coach program builder.
//

import Foundation

enum CoachRecommendationEngine {

    struct RederiveResult: Equatable, Sendable {
        var blueprint: CoachBlueprint
        var autoUpdates: [CoachRecommendationChange]
    }

    // MARK: - Public

    static func buildBlueprint(from intake: CoachIntakeSnapshot) -> CoachBlueprint {
        let sessions = resolvedSessionsPerWeek(intake: intake)
        let weekdays = CoachScheduleSync.reconcile(
            sessions: sessions,
            weekdays: intake.preferredWeekdays
        ).weekdays
        let programming = CoachGoalProgramming.resolve(
            from: intake.primaryGoal,
            experienceLevel: intake.experienceLevel
        )
        let splitDecision = recommendedSplit(intake: intake, sessions: sessions, programming: programming)
        let totalWeeks = recommendedProgramLength(intake: intake, programming: programming)
        let structure = recommendedPhaseStructure(
            intake: intake,
            totalWeeks: totalWeeks,
            programming: programming
        )
        let cardio = recommendedCardio(intake: intake, sessions: sessions, programming: programming)
        let intensity = programming.intensityStyle
        let progression = programming.progressionStyle
        let deload = programming.deloadPreference
        let programName = recommendedProgramName(intake: intake, programming: programming)
        let recoveryNotes = recoveryContextNotes(from: intake)
        let warnings = buildWarnings(
            intake: intake,
            sessions: sessions,
            weekdays: weekdays,
            split: splitDecision.split,
            cardio: cardio
        )

        let recommendations: [CoachRecommendation] = [
            CoachRecommendation(
                topic: .programName,
                recommendedValue: programName,
                rationale: localRationale(
                    for: .programName,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .split,
                recommendedValue: splitDecision.split,
                rationale: localRationale(
                    for: .split,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .programLength,
                recommendedValue: "\(totalWeeks) weeks",
                rationale: localRationale(
                    for: .programLength,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .cardio,
                recommendedValue: cardioSummary(cardio),
                rationale: localRationale(
                    for: .cardio,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .periodization,
                recommendedValue: structure.summaryLabel,
                rationale: localRationale(
                    for: .periodization,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .intensity,
                recommendedValue: intensity,
                rationale: localRationale(
                    for: .intensity,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .progression,
                recommendedValue: progression,
                rationale: localRationale(
                    for: .progression,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                )
            ),
            CoachRecommendation(
                topic: .deload,
                recommendedValue: deload,
                rationale: localRationale(
                    for: .deload,
                    intake: intake,
                    sessions: sessions,
                    split: splitDecision.split,
                    weeks: totalWeeks,
                    cardio: cardio,
                    structure: structure,
                    programming: programming,
                    usedSavedSplit: splitDecision.usedSaved
                ),
                confidence: intake.experienceLevel.lowercased().contains("beginner") ? .medium : .high
            ),
        ]

        return CoachBlueprint(
            programName: programName,
            sessionsPerWeek: sessions,
            preferredWeekdays: weekdays,
            primaryGoal: intake.primaryGoal,
            equipment: intake.equipment,
            experienceLevel: intake.experienceLevel,
            splitPreference: splitDecision.split,
            totalWeeks: totalWeeks,
            isPeriodized: structure.isPeriodized,
            blockSpecs: structure.blockSpecs,
            cardioConfiguration: cardio,
            intensityStyle: intensity,
            progressionStyle: progression,
            deloadPreference: deload,
            busyDayPolicy: .skip,
            limitationsNotes: intake.limitationsNotes,
            additionalNotes: intake.additionalNotes,
            sessionDurationMinutes: intake.sessionDurationMinutes,
            priorityMusclesOrLiftsNotes: intake.priorityMusclesOrLiftsNotes,
            recoveryContextNotes: recoveryNotes,
            usedSavedSplitPreference: splitDecision.usedSaved,
            recommendations: recommendations,
            warnings: warnings,
            changes: []
        )
    }

    static func applyRecommendationChange(
        to blueprint: inout CoachBlueprint,
        topic: CoachRecommendationTopic,
        newValue: String
    ) -> CoachRecommendationChange? {
        guard let index = blueprint.recommendations.firstIndex(where: { $0.topic == topic }) else { return nil }
        let before = blueprint.recommendations[index].finalValue
        guard before != newValue else { return nil }

        blueprint.recommendations[index].finalValue = newValue
        blueprint.recommendations[index].isAccepted = true
        syncBlueprintFields(from: &blueprint, topic: topic, value: newValue)

        let change = CoachRecommendationChange(topic: topic, beforeValue: before, afterValue: newValue)
        blueprint.changes.removeAll { $0.topic == topic }
        blueprint.changes.append(change)
        return change
    }

    static func applyScheduleChange(
        to blueprint: inout CoachBlueprint,
        sessions: Int,
        weekdays: [Int]
    ) {
        let reconciled = CoachScheduleSync.reconcile(sessions: sessions, weekdays: weekdays)
        blueprint.sessionsPerWeek = reconciled.sessions
        blueprint.preferredWeekdays = reconciled.weekdays
    }

    /// Re-derive unlocked recommendations from a fresh blueprint built from `intake`.
    /// Locked rows (`userChangedFromRecommendation`) keep their final values.
    static func rederive(blueprint: inout CoachBlueprint, intake: CoachIntakeSnapshot) -> [CoachRecommendationChange] {
        let fresh = buildBlueprint(from: intake)
        var autoUpdates: [CoachRecommendationChange] = []

        for topic in CoachRecommendationTopic.allCases {
            guard let freshRec = fresh.recommendation(for: topic),
                  let index = blueprint.recommendations.firstIndex(where: { $0.topic == topic }) else {
                continue
            }
            let existing = blueprint.recommendations[index]
            if existing.userChangedFromRecommendation {
                continue
            }
            let before = existing.finalValue
            let after = freshRec.recommendedValue
            blueprint.recommendations[index].recommendedValue = after
            blueprint.recommendations[index].finalValue = after
            blueprint.recommendations[index].rationale = freshRec.rationale
            blueprint.recommendations[index].confidence = freshRec.confidence
            syncBlueprintFields(from: &blueprint, topic: topic, value: after)
            if before != after {
                let change = CoachRecommendationChange(topic: topic, beforeValue: before, afterValue: after)
                autoUpdates.append(change)
            }
        }

        // Keep schedule / intake-derived fields aligned.
        blueprint.sessionsPerWeek = fresh.sessionsPerWeek
        blueprint.preferredWeekdays = fresh.preferredWeekdays
        blueprint.sessionDurationMinutes = intake.sessionDurationMinutes
        blueprint.priorityMusclesOrLiftsNotes = intake.priorityMusclesOrLiftsNotes
        blueprint.recoveryContextNotes = recoveryContextNotes(from: intake)
        blueprint.primaryGoal = intake.primaryGoal
        blueprint.equipment = intake.equipment
        blueprint.experienceLevel = intake.experienceLevel
        blueprint.limitationsNotes = intake.limitationsNotes
        blueprint.usedSavedSplitPreference = fresh.usedSavedSplitPreference

        recomputeWarnings(blueprint: &blueprint, intake: intake)
        return autoUpdates
    }

    static func recomputeWarnings(blueprint: inout CoachBlueprint, intake: CoachIntakeSnapshot) {
        let local = buildWarnings(
            intake: intake,
            sessions: blueprint.sessionsPerWeek,
            weekdays: blueprint.preferredWeekdays,
            split: blueprint.splitPreference,
            cardio: blueprint.cardioConfiguration
        )
        // Preserve AI-appended warnings that aren't reproduced locally.
        let extras = blueprint.warnings.filter { !local.contains($0) }
        blueprint.warnings = local + extras
    }

    static func syncBlueprintFromRecommendations(_ blueprint: inout CoachBlueprint) {
        for rec in blueprint.recommendations {
            syncBlueprintFields(from: &blueprint, topic: rec.topic, value: rec.finalValue)
        }
    }

    // MARK: - Sessions

    private static func resolvedSessionsPerWeek(intake: CoachIntakeSnapshot) -> Int {
        let raw: Int
        if intake.sessionsPerWeek > 0 {
            raw = intake.sessionsPerWeek
        } else if let inferred = intake.inferredSessionsPerWeek {
            raw = inferred
        } else {
            let exp = intake.experienceLevel.lowercased()
            if exp.contains("beginner") {
                raw = 3
            } else if exp.contains("advanced") {
                raw = 5
            } else {
                raw = 4
            }
        }
        return CoachScheduleSync.clampSessions(raw, to: intake.preferredWeekdays)
    }

    // MARK: - Split

    private struct SplitDecision {
        let split: String
        let usedSaved: Bool
    }

    private static func recommendedSplit(
        intake: CoachIntakeSnapshot,
        sessions: Int,
        programming: CoachGoalProgramming
    ) -> SplitDecision {
        let goalSplit = goalBasedSplit(sessions: sessions, programming: programming)

        if let saved = intake.savedSplitPreference,
           !saved.contains("No preference"),
           CoachSplitPick.allCases.contains(where: { $0.rawValue == saved }),
           isSplitCompatible(saved, sessions: sessions, programming: programming) {
            return SplitDecision(split: saved, usedSaved: true)
        }

        return SplitDecision(split: goalSplit, usedSaved: false)
    }

    private static func goalBasedSplit(sessions: Int, programming: CoachGoalProgramming) -> String {
        if sessions <= 3 {
            return CoachSplitPick.fullBody.rawValue
        }

        switch programming.goal {
        case .buildMuscle:
            if sessions >= 5 {
                return CoachSplitPick.broSplit.rawValue
            }
            return CoachSplitPick.upperLower.rawValue
        case .strength:
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        case .fatLoss:
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        case .performance:
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        case .general:
            if sessions >= 5 {
                return CoachSplitPick.pushPullLegs.rawValue
            }
            if sessions == 4 {
                return CoachSplitPick.upperLower.rawValue
            }
            return CoachSplitPick.fullBody.rawValue
        }
    }

    private static func isSplitCompatible(_ split: String, sessions: Int, programming: CoachGoalProgramming) -> Bool {
        if split.contains("Push / Pull / Legs") && sessions < 3 {
            return false
        }
        if split.contains("bro") && sessions < 4 {
            return false
        }
        // Saved preference that conflicts with beginner/low-frequency full-body default is still OK
        // if sessions allow — goalBasedSplit already encodes soft preferences.
        _ = programming
        return true
    }

    // MARK: - Program length

    private static func recommendedProgramLength(
        intake: CoachIntakeSnapshot,
        programming: CoachGoalProgramming
    ) -> Int {
        _ = intake
        return programming.defaultWeeks
    }

    // MARK: - Phase structure

    private struct PhaseStructure {
        let isPeriodized: Bool
        let blockSpecs: [DynamicBlockGenerationSpec]
        let summaryLabel: String
    }

    private static func recommendedPhaseStructure(
        intake: CoachIntakeSnapshot,
        totalWeeks: Int,
        programming: CoachGoalProgramming
    ) -> PhaseStructure {
        let exp = intake.experienceLevel.lowercased()
        let isBeginner = exp.contains("beginner")

        if isBeginner || programming.goal == .general {
            let block = DynamicBlockGenerationSpec(
                title: "Training",
                focus: BlockFocus(kind: .general, emphasisLabel: ""),
                durationWeeks: totalWeeks,
                progressionStrategy: .doubleProgression
            )
            return PhaseStructure(
                isPeriodized: false,
                blockSpecs: [block],
                summaryLabel: "One continuous phase — \(totalWeeks) weeks"
            )
        }

        switch programming.goal {
        case .buildMuscle:
            // Longer hypertrophy emphasis, shorter strength peak.
            let w1 = max(1, (totalWeeks * 2) / 3)
            let w2 = max(1, totalWeeks - w1)
            return PhaseStructure(
                isPeriodized: true,
                blockSpecs: [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1: Hypertrophy",
                        focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                        durationWeeks: w1,
                        progressionStrategy: .doubleProgression
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2: Strength support",
                        focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                        durationWeeks: w2,
                        progressionStrategy: .linear
                    ),
                ],
                summaryLabel: "Two phases — build, then peak"
            )

        case .strength:
            // Shorter accumulation into a longer strength block.
            let w1 = max(1, totalWeeks / 3)
            let w2 = max(1, totalWeeks - w1)
            return PhaseStructure(
                isPeriodized: true,
                blockSpecs: [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1: Accumulation",
                        focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                        durationWeeks: w1,
                        progressionStrategy: .doubleProgression
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2: Strength",
                        focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                        durationWeeks: w2,
                        progressionStrategy: .linear
                    ),
                ],
                summaryLabel: "Two phases — build, then peak"
            )

        case .fatLoss:
            let block = DynamicBlockGenerationSpec(
                title: "Fat loss training",
                focus: BlockFocus(kind: .general, emphasisLabel: "Density"),
                durationWeeks: totalWeeks,
                progressionStrategy: .doubleProgression
            )
            return PhaseStructure(
                isPeriodized: false,
                blockSpecs: [block],
                summaryLabel: "One continuous phase — \(totalWeeks) weeks"
            )

        case .performance:
            let w1 = max(1, totalWeeks / 2)
            let w2 = max(1, totalWeeks - w1)
            return PhaseStructure(
                isPeriodized: true,
                blockSpecs: [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1: Strength & power",
                        focus: BlockFocus(kind: .strength, emphasisLabel: "Power"),
                        durationWeeks: w1,
                        progressionStrategy: .linear
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2: Conditioning emphasis",
                        focus: BlockFocus(kind: .general, emphasisLabel: "Conditioning"),
                        durationWeeks: w2,
                        progressionStrategy: .doubleProgression
                    ),
                ],
                summaryLabel: "Two phases — build, then peak"
            )

        case .general:
            let block = DynamicBlockGenerationSpec(
                title: "Training",
                focus: BlockFocus(kind: .general, emphasisLabel: ""),
                durationWeeks: totalWeeks,
                progressionStrategy: .doubleProgression
            )
            return PhaseStructure(
                isPeriodized: false,
                blockSpecs: [block],
                summaryLabel: "One continuous phase — \(totalWeeks) weeks"
            )
        }
    }

    // MARK: - Cardio

    private static func recommendedCardio(
        intake: CoachIntakeSnapshot,
        sessions: Int,
        programming: CoachGoalProgramming
    ) -> CardioProgramConfiguration {
        let hasLimitations = !intake.limitationsNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !intake.limitationsNotes.lowercased().contains("none")

        let cardioGoal: CardioProgramGoal
        let preference: CardioProgramPreference

        switch programming.goal {
        case .fatLoss:
            cardioGoal = .fatLoss
            preference = sessions >= 4 ? .mixed : .postWorkout
        case .performance:
            cardioGoal = .enduranceBuilding
            preference = sessions >= 5 ? .mixed : .dedicatedDays
        case .buildMuscle, .strength:
            cardioGoal = .generalHealth
            preference = .postWorkout
        case .general:
            cardioGoal = .generalHealth
            preference = .postWorkout
        }

        let dedicatedDays: Int
        if preference.includesDedicatedCardioDays {
            dedicatedDays = min(2, max(1, sessions / 2))
        } else {
            dedicatedDays = 2
        }

        let weeklyProgression: Int
        switch cardioGoal {
        case .fatLoss: weeklyProgression = 5
        case .enduranceBuilding, .racePrep: weeklyProgression = 10
        default: weeklyProgression = hasLimitations ? 0 : 5
        }

        return CardioProgramConfiguration(
            goal: cardioGoal,
            preference: preference,
            dedicatedDayCount: dedicatedDays,
            finisherDurationMinutes: 10,
            finisherZone: cardioGoal == .fatLoss ? .zone3 : .zone2,
            weeklyProgressionMinutes: weeklyProgression
        )
    }

    private static func cardioSummary(_ config: CardioProgramConfiguration) -> String {
        if config.preference == .none {
            return CoachCardioPick.none.rawValue
        }
        if let pick = CoachCardioPick.allCases.first(where: { $0.preference == config.preference }) {
            return pick.rawValue
        }
        var parts: [String] = [config.preference.rawValue]
        if config.preference.includesDedicatedCardioDays {
            parts.append("\(config.dedicatedDayCount) dedicated day\(config.dedicatedDayCount == 1 ? "" : "s")")
        }
        if config.preference.includesPostWorkoutFinishers {
            parts.append("\(config.finisherDurationMinutes)-min finishers")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Naming / recovery

    private static func recommendedProgramName(
        intake: CoachIntakeSnapshot,
        programming: CoachGoalProgramming
    ) -> String {
        _ = intake
        switch programming.goal {
        case .buildMuscle: return "Muscle building program"
        case .strength: return "Strength program"
        case .fatLoss: return "Fat loss program"
        case .performance: return "Performance program"
        case .general: return "My training program"
        }
    }

    private static func recoveryContextNotes(from intake: CoachIntakeSnapshot) -> String {
        var parts: [String] = []
        if let inferred = intake.inferredSessionsPerWeek {
            parts.append("Recent training frequency ≈ \(inferred) sessions/week.")
        }
        let limitations = intake.limitationsNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !limitations.isEmpty, !limitations.lowercased().contains("none") {
            parts.append("Limitations: \(limitations)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Warnings

    private static func buildWarnings(
        intake: CoachIntakeSnapshot,
        sessions: Int,
        weekdays: [Int],
        split: String,
        cardio: CardioProgramConfiguration
    ) -> [String] {
        var warnings: [String] = []
        let exp = intake.experienceLevel.lowercased()
        let limitations = intake.limitationsNotes.lowercased()

        if exp.contains("beginner") && sessions >= 5 {
            warnings.append("Five or more days may be a lot for a beginner — we can always scale back if recovery suffers.")
        }

        if !limitations.isEmpty && !limitations.contains("none") {
            warnings.append("I'll keep volume conservative because of your limitations. Consider checking with a clinician if anything feels painful.")
        }

        if split.contains("Push / Pull / Legs") && sessions < 3 {
            warnings.append("Push/Pull/Legs works best with at least 3 sessions per week.")
        }

        if cardio.preference == .mixed && sessions <= 3 {
            warnings.append("Mixed cardio plus lifting on only \(sessions) days can feel crowded — finishers may be enough.")
        }

        if !weekdays.isEmpty && sessions > weekdays.count {
            warnings.append("Sessions per week (\(sessions)) exceeds the number of preferred days (\(weekdays.count)).")
        }

        return warnings
    }

    // MARK: - Local rationale templates

    private static func localRationale(
        for topic: CoachRecommendationTopic,
        intake: CoachIntakeSnapshot,
        sessions: Int,
        split: String,
        weeks: Int,
        cardio: CardioProgramConfiguration,
        structure: PhaseStructure,
        programming: CoachGoalProgramming,
        usedSavedSplit: Bool
    ) -> String {
        switch topic {
        case .programName:
            return "A clear name helps you stay oriented as blocks change over time."
        case .split:
            if usedSavedSplit {
                return "Using your saved preference (\(split)) — it still fits \(sessions) days/week and your \(programming.goal.rawValue.lowercased()) goal."
            }
            return "With \(sessions) days per week and your \(programming.goal.rawValue.lowercased()) goal, \(split) gives you solid frequency without spreading yourself too thin."
        case .programLength:
            return "\(weeks) weeks matches a \(programming.goal.rawValue.lowercased()) focus — enough time to progress without the plan dragging on."
        case .cardio:
            if cardio.preference == .none {
                return "Your main focus is lifting right now, so we'll skip extra cardio and protect recovery."
            }
            return "\(programming.cardioDensity) This keeps conditioning aligned with \(programming.goal.rawValue.lowercased())."
        case .periodization:
            return structure.summaryLabel + ". Tuned for \(programming.goal.rawValue.lowercased()) rather than a one-size-fits-all timeline."
        case .intensity:
            return "\(programming.intensityStyle) — \(programming.repBias)."
        case .progression:
            return "\(programming.progressionStyle) keeps progress measurable for your experience level."
        case .deload:
            return "Planned easier weeks help you absorb hard training and come back stronger."
        }
    }

    // MARK: - Sync blueprint fields from recommendation edits

    private static func syncBlueprintFields(from blueprint: inout CoachBlueprint, topic: CoachRecommendationTopic, value: String) {
        switch topic {
        case .programName:
            blueprint.programName = value
        case .split:
            blueprint.splitPreference = value
        case .programLength:
            if let pick = CoachProgramLengthPick.allCases.first(where: { $0.label == value || value.contains("\($0.rawValue)") }) {
                blueprint.totalWeeks = pick.rawValue
                rebuildBlockDurations(blueprint: &blueprint)
            } else if let weeks = Int(value.filter(\.isNumber)), weeks > 0 {
                blueprint.totalWeeks = min(52, weeks)
                rebuildBlockDurations(blueprint: &blueprint)
            }
        case .cardio:
            if let pick = CoachCardioPick.allCases.first(where: { $0.rawValue == value }) {
                blueprint.cardioConfiguration.preference = pick.preference
            } else if value.lowercased().contains("none") || value.lowercased().contains("strength only") {
                blueprint.cardioConfiguration.preference = .none
            } else if value.lowercased().contains("mixed") {
                blueprint.cardioConfiguration.preference = .mixed
            } else if value.lowercased().contains("dedicated") {
                blueprint.cardioConfiguration.preference = .dedicatedDays
            } else if value.lowercased().contains("finisher") || value.lowercased().contains("light") {
                blueprint.cardioConfiguration.preference = .postWorkout
            }
            if let match = value.range(of: #"(\d+)\s*dedicated"#, options: .regularExpression) {
                let digits = value[match].filter(\.isNumber)
                if let count = Int(digits) {
                    blueprint.cardioConfiguration.dedicatedDayCount = min(4, max(1, count))
                }
            }
        case .periodization:
            if value.lowercased().contains("three") {
                blueprint.isPeriodized = true
                let total = blueprint.totalWeeks
                let w1 = max(1, (total * 2) / 5)
                let w2 = max(1, (total * 2) / 5)
                let w3 = max(1, total - w1 - w2)
                blueprint.blockSpecs = [
                    DynamicBlockGenerationSpec(title: "Phase 1: Build", focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""), durationWeeks: w1, progressionStrategy: .doubleProgression),
                    DynamicBlockGenerationSpec(title: "Phase 2: Peak", focus: BlockFocus(kind: .strength, emphasisLabel: ""), durationWeeks: w2, progressionStrategy: .linear),
                    DynamicBlockGenerationSpec(title: "Phase 3: Recover", focus: BlockFocus(kind: .deload, emphasisLabel: ""), durationWeeks: w3, progressionStrategy: .doubleProgression, volumeMultiplier: 0.7, isDeloadBlock: true),
                ]
            } else if value.lowercased().contains("two") {
                // Prefer goal-aware two-phase when possible.
                let programming = CoachGoalProgramming.resolve(
                    from: blueprint.primaryGoal,
                    experienceLevel: blueprint.experienceLevel
                )
                let rebuilt = recommendedPhaseStructure(
                    intake: CoachIntakeSnapshot(
                        primaryGoal: blueprint.primaryGoal,
                        experienceLevel: blueprint.experienceLevel,
                        sessionsPerWeek: blueprint.sessionsPerWeek
                    ),
                    totalWeeks: blueprint.totalWeeks,
                    programming: programming
                )
                if rebuilt.isPeriodized && rebuilt.blockSpecs.count == 2 {
                    blueprint.isPeriodized = true
                    blueprint.blockSpecs = rebuilt.blockSpecs
                } else {
                    blueprint.isPeriodized = true
                    let w1 = max(1, blueprint.totalWeeks / 2)
                    let w2 = max(1, blueprint.totalWeeks - w1)
                    blueprint.blockSpecs = [
                        DynamicBlockGenerationSpec(title: "Phase 1: Build muscle", focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""), durationWeeks: w1, progressionStrategy: .doubleProgression),
                        DynamicBlockGenerationSpec(title: "Phase 2: Get stronger", focus: BlockFocus(kind: .strength, emphasisLabel: ""), durationWeeks: w2, progressionStrategy: .linear),
                    ]
                }
            } else {
                blueprint.isPeriodized = false
                blueprint.blockSpecs = [
                    DynamicBlockGenerationSpec(
                        title: "Training",
                        focus: BlockFocus(kind: .general, emphasisLabel: ""),
                        durationWeeks: blueprint.totalWeeks,
                        progressionStrategy: .doubleProgression
                    ),
                ]
            }
        case .intensity:
            blueprint.intensityStyle = value
        case .progression:
            blueprint.progressionStyle = value
        case .deload:
            blueprint.deloadPreference = value
        }
    }

    private static func rebuildBlockDurations(blueprint: inout CoachBlueprint) {
        guard !blueprint.blockSpecs.isEmpty else { return }
        if blueprint.isPeriodized {
            if blueprint.blockSpecs.count == 2 {
                // Preserve relative emphasis (e.g. 2/3 hypertrophy vs 1/3 strength) when possible.
                let total = max(1, blueprint.blockSpecs.map(\.durationWeeks).reduce(0, +))
                let ratio0 = Double(blueprint.blockSpecs[0].durationWeeks) / Double(total)
                var w1 = max(1, Int((Double(blueprint.totalWeeks) * ratio0).rounded()))
                w1 = min(w1, blueprint.totalWeeks - 1)
                let w2 = max(1, blueprint.totalWeeks - w1)
                blueprint.blockSpecs[0].durationWeeks = w1
                blueprint.blockSpecs[1].durationWeeks = w2
            } else if blueprint.blockSpecs.count >= 3 {
                let total = blueprint.totalWeeks
                let w1 = max(1, (total * 2) / 5)
                let w2 = max(1, (total * 2) / 5)
                let w3 = max(1, total - w1 - w2)
                blueprint.blockSpecs[0].durationWeeks = w1
                blueprint.blockSpecs[1].durationWeeks = w2
                blueprint.blockSpecs[2].durationWeeks = w3
            }
        } else {
            blueprint.blockSpecs[0].durationWeeks = blueprint.totalWeeks
        }
    }
}
