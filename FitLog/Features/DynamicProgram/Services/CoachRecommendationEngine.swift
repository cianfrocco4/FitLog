//
//  CoachRecommendationEngine.swift
//  FitLog
//
//  Deterministic local recommendations for the Guided Coach program builder.
//

import Foundation

enum CoachRecommendationEngine {

    // MARK: - Public

    static func buildBlueprint(from intake: CoachIntakeSnapshot) -> CoachBlueprint {
        let sessions = resolvedSessionsPerWeek(intake: intake)
        let split = recommendedSplit(intake: intake, sessions: sessions)
        let totalWeeks = recommendedProgramLength(intake: intake)
        let structure = recommendedPhaseStructure(intake: intake, totalWeeks: totalWeeks)
        let cardio = recommendedCardio(intake: intake, sessions: sessions)
        let intensity = recommendedIntensity(intake: intake)
        let progression = recommendedProgression(intake: intake)
        let deload = recommendedDeload(intake: intake)
        let programName = recommendedProgramName(intake: intake)
        let warnings = buildWarnings(intake: intake, sessions: sessions, split: split, cardio: cardio)

        let recommendations: [CoachRecommendation] = [
            CoachRecommendation(
                topic: .programName,
                recommendedValue: programName,
                rationale: localRationale(for: .programName, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .split,
                recommendedValue: split,
                rationale: localRationale(for: .split, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .programLength,
                recommendedValue: "\(totalWeeks) weeks",
                rationale: localRationale(for: .programLength, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .cardio,
                recommendedValue: cardioSummary(cardio),
                rationale: localRationale(for: .cardio, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .periodization,
                recommendedValue: structure.summaryLabel,
                rationale: localRationale(for: .periodization, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .intensity,
                recommendedValue: intensity,
                rationale: localRationale(for: .intensity, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .progression,
                recommendedValue: progression,
                rationale: localRationale(for: .progression, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure)
            ),
            CoachRecommendation(
                topic: .deload,
                recommendedValue: deload,
                rationale: localRationale(for: .deload, intake: intake, sessions: sessions, split: split, weeks: totalWeeks, cardio: cardio, structure: structure),
                confidence: intake.experienceLevel.lowercased().contains("beginner") ? .medium : .high
            ),
        ]

        return CoachBlueprint(
            programName: programName,
            sessionsPerWeek: sessions,
            preferredWeekdays: intake.preferredWeekdays,
            primaryGoal: intake.primaryGoal,
            equipment: intake.equipment,
            experienceLevel: intake.experienceLevel,
            splitPreference: split,
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

    static func syncBlueprintFromRecommendations(_ blueprint: inout CoachBlueprint) {
        for rec in blueprint.recommendations {
            syncBlueprintFields(from: &blueprint, topic: rec.topic, value: rec.finalValue)
        }
    }

    // MARK: - Sessions

    private static func resolvedSessionsPerWeek(intake: CoachIntakeSnapshot) -> Int {
        if intake.sessionsPerWeek > 0 {
            return min(7, max(1, intake.sessionsPerWeek))
        }
        if let inferred = intake.inferredSessionsPerWeek {
            return min(7, max(1, inferred))
        }
        let exp = intake.experienceLevel.lowercased()
        if exp.contains("beginner") { return 3 }
        if exp.contains("advanced") { return 5 }
        return 4
    }

    // MARK: - Split

    private static func recommendedSplit(intake: CoachIntakeSnapshot, sessions: Int) -> String {
        if let saved = intake.savedSplitPreference,
           !saved.contains("No preference"),
           CoachSplitPick.allCases.contains(where: { $0.rawValue == saved }) {
            return saved
        }

        let goal = intake.primaryGoal.lowercased()
        let exp = intake.experienceLevel.lowercased()

        if exp.contains("beginner") || sessions <= 3 {
            return CoachSplitPick.fullBody.rawValue
        }

        if goal.contains("fat loss") || goal.contains("conditioning") {
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        }

        if goal.contains("stronger") || goal.contains("strength") {
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        }

        if goal.contains("athletic") || goal.contains("performance") {
            return sessions >= 5 ? CoachSplitPick.pushPullLegs.rawValue : CoachSplitPick.upperLower.rawValue
        }

        if sessions >= 5 {
            return CoachSplitPick.pushPullLegs.rawValue
        }
        if sessions == 4 {
            return CoachSplitPick.upperLower.rawValue
        }
        return CoachSplitPick.fullBody.rawValue
    }

    // MARK: - Program length

    private static func recommendedProgramLength(intake: CoachIntakeSnapshot) -> Int {
        let exp = intake.experienceLevel.lowercased()
        let goal = intake.primaryGoal.lowercased()

        if exp.contains("beginner") { return 8 }
        if exp.contains("advanced") {
            return goal.contains("athletic") || goal.contains("performance") ? 12 : 12
        }
        if goal.contains("fat loss") { return 8 }
        return 8
    }

    // MARK: - Phase structure

    private struct PhaseStructure {
        let isPeriodized: Bool
        let blockSpecs: [DynamicBlockGenerationSpec]
        let summaryLabel: String
    }

    private static func recommendedPhaseStructure(intake: CoachIntakeSnapshot, totalWeeks: Int) -> PhaseStructure {
        let exp = intake.experienceLevel.lowercased()
        let goal = intake.primaryGoal.lowercased()

        if exp.contains("beginner") || goal.contains("general fitness") {
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

        if goal.contains("stronger") || goal.contains("strength") || goal.contains("muscle") {
            let w1 = max(1, totalWeeks / 2)
            let w2 = max(1, totalWeeks - w1)
            return PhaseStructure(
                isPeriodized: true,
                blockSpecs: [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1: Build muscle",
                        focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                        durationWeeks: w1,
                        progressionStrategy: .doubleProgression
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2: Get stronger",
                        focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                        durationWeeks: w2,
                        progressionStrategy: .linear
                    ),
                ],
                summaryLabel: "Two phases — \(w1) weeks build, then \(w2) weeks strength"
            )
        }

        if exp.contains("advanced") && totalWeeks >= 12 {
            let w1 = max(1, (totalWeeks * 2) / 5)
            let w2 = max(1, (totalWeeks * 2) / 5)
            let w3 = max(1, totalWeeks - w1 - w2)
            return PhaseStructure(
                isPeriodized: true,
                blockSpecs: [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1: Build",
                        focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                        durationWeeks: w1,
                        progressionStrategy: .doubleProgression
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2: Peak",
                        focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                        durationWeeks: w2,
                        progressionStrategy: .linear
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 3: Recover",
                        focus: BlockFocus(kind: .deload, emphasisLabel: ""),
                        durationWeeks: w3,
                        progressionStrategy: .doubleProgression,
                        volumeMultiplier: 0.7,
                        isDeloadBlock: true
                    ),
                ],
                summaryLabel: "Three phases — build, peak, then recover"
            )
        }

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

    // MARK: - Cardio

    private static func recommendedCardio(intake: CoachIntakeSnapshot, sessions: Int) -> CardioProgramConfiguration {
        let goal = intake.primaryGoal.lowercased()
        let hasLimitations = !intake.limitationsNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !intake.limitationsNotes.lowercased().contains("none")

        let cardioGoal: CardioProgramGoal
        let preference: CardioProgramPreference

        if goal.contains("fat loss") || goal.contains("conditioning") {
            cardioGoal = .fatLoss
            preference = sessions >= 4 ? .mixed : .postWorkout
        } else if goal.contains("athletic") || goal.contains("performance") {
            cardioGoal = .enduranceBuilding
            preference = sessions >= 5 ? .mixed : .dedicatedDays
        } else if goal.contains("stronger") || goal.contains("muscle") {
            cardioGoal = .generalHealth
            preference = .postWorkout
        } else {
            cardioGoal = .generalHealth
            preference = hasLimitations ? .postWorkout : .postWorkout
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
            finisherDurationMinutes: preference.includesPostWorkoutFinishers ? 10 : 10,
            finisherZone: cardioGoal == .fatLoss ? .zone3 : .zone2,
            weeklyProgressionMinutes: weeklyProgression
        )
    }

    private static func cardioSummary(_ config: CardioProgramConfiguration) -> String {
        if config.preference == .none {
            return CardioProgramPreference.none.rawValue
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

    // MARK: - Style defaults

    private static func recommendedIntensity(intake: CoachIntakeSnapshot) -> String {
        let goal = intake.primaryGoal.lowercased()
        if goal.contains("stronger") || goal.contains("strength") {
            return "Heavier loads, lower reps"
        }
        if goal.contains("fat loss") {
            return "Moderate loads, controlled reps (RPE ~7–8)"
        }
        return "Balanced (mix of heavy and moderate)"
    }

    private static func recommendedProgression(intake: CoachIntakeSnapshot) -> String {
        let exp = intake.experienceLevel.lowercased()
        if exp.contains("beginner") {
            return "Linear / add weight when form is solid"
        }
        return "Double progression (reps then weight)"
    }

    private static func recommendedDeload(intake: CoachIntakeSnapshot) -> String {
        let exp = intake.experienceLevel.lowercased()
        if exp.contains("advanced") {
            return "Lighter week about every 4th week"
        }
        return "Deload when I feel run-down"
    }

    private static func recommendedProgramName(intake: CoachIntakeSnapshot) -> String {
        let goal = intake.primaryGoal
        if goal.contains("muscle") { return "Muscle building program" }
        if goal.contains("stronger") || goal.contains("strength") { return "Strength program" }
        if goal.contains("fat loss") { return "Fat loss program" }
        if goal.contains("Athletic") || goal.contains("performance") { return "Performance program" }
        return "My training program"
    }

    // MARK: - Warnings

    private static func buildWarnings(
        intake: CoachIntakeSnapshot,
        sessions: Int,
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
        structure: PhaseStructure
    ) -> String {
        switch topic {
        case .programName:
            return "A clear name helps you stay oriented as blocks change over time."
        case .split:
            return "With \(sessions) days per week and your \(intake.primaryGoal.lowercased()) goal, \(split) gives you solid frequency without spreading yourself too thin."
        case .programLength:
            return "\(weeks) weeks is enough time to see meaningful progress without dragging on so long that motivation fades."
        case .cardio:
            if cardio.preference == .none {
                return "Your main focus is lifting right now, so we'll skip extra cardio and protect recovery."
            }
            return "This keeps conditioning in the program without stealing recovery from your main lifting work."
        case .periodization:
            return structure.summaryLabel + ". This lets you build, then shift emphasis as your body adapts."
        case .intensity:
            return "This intensity style matches your goal and experience so sessions stay productive but manageable."
        case .progression:
            return "You'll add reps first, then weight — a reliable way to progress without guessing."
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
                blueprint.isPeriodized = true
                let w1 = max(1, blueprint.totalWeeks / 2)
                let w2 = max(1, blueprint.totalWeeks - w1)
                blueprint.blockSpecs = [
                    DynamicBlockGenerationSpec(title: "Phase 1: Build muscle", focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""), durationWeeks: w1, progressionStrategy: .doubleProgression),
                    DynamicBlockGenerationSpec(title: "Phase 2: Get stronger", focus: BlockFocus(kind: .strength, emphasisLabel: ""), durationWeeks: w2, progressionStrategy: .linear),
                ]
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
                let w1 = max(1, blueprint.totalWeeks / 2)
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
