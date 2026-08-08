//
//  CoachConversationModels.swift
//  FitLog
//
//  Domain models for the Guided Coach conversational program builder.
//

import Foundation

// MARK: - Phases

enum CoachPhase: String, Sendable, Equatable {
    case intake
    case planPreview
    case generating
    case complete
}

// MARK: - Intake

enum CoachIntakeTopic: String, CaseIterable, Sendable, Equatable {
    case goal
    case goalFollowUp
    case experience
    case schedule
    case sessionDuration
    case equipment
    case constraints

    /// Default Guided Coach question order. `goalFollowUp` is inserted dynamically when relevant.
    static var standardIntakeOrder: [CoachIntakeTopic] {
        [.goal, .experience, .schedule, .sessionDuration, .equipment, .constraints]
    }
}

enum CoachQuestionResponseKind: Sendable, Equatable {
    case quickReplies
    case schedule
    case textOptional
}

struct CoachQuestion: Identifiable, Equatable, Sendable {
    let id: UUID
    let topic: CoachIntakeTopic
    let prompt: String
    let responseKind: CoachQuestionResponseKind
    let quickReplies: [String]

    init(
        id: UUID = UUID(),
        topic: CoachIntakeTopic,
        prompt: String,
        responseKind: CoachQuestionResponseKind,
        quickReplies: [String] = []
    ) {
        self.id = id
        self.topic = topic
        self.prompt = prompt
        self.responseKind = responseKind
        self.quickReplies = quickReplies
    }
}

/// Collected intake answers before recommendations are generated.
struct CoachIntakeSnapshot: Equatable, Sendable {
    var primaryGoal: String = "General fitness & health"
    var experienceLevel: String = "Intermediate"
    var sessionsPerWeek: Int = 3
    var preferredWeekdays: [Int] = []
    var equipment: String = "Full gym (machines + free weights)"
    var limitationsNotes: String = ""
    var additionalNotes: String = ""
    /// Typical session length in minutes; nil = unspecified.
    var sessionDurationMinutes: Int?
    /// Sport / priority lifts from goal follow-up.
    var priorityMusclesOrLiftsNotes: String = ""
    /// Optional context from workout history (sessions/week estimate).
    var inferredSessionsPerWeek: Int?
    /// Optional saved split preference from prior builder visits.
    var savedSplitPreference: String?
}

// MARK: - Recommendations

enum CoachRecommendationTopic: String, CaseIterable, Codable, Sendable, Equatable {
    case programName
    case split
    case programLength
    case cardio
    case periodization
    case intensity
    case progression
    case deload

    var title: String {
        switch self {
        case .programName: return "Program name"
        case .split: return "Split style"
        case .programLength: return "Program length"
        case .cardio: return "Cardio plan"
        case .periodization: return "Training phases"
        case .intensity: return "Intensity style"
        case .progression: return "Progression style"
        case .deload: return "Deload approach"
        }
    }

    var systemImage: String {
        switch self {
        case .programName: return "textformat"
        case .split: return "calendar"
        case .programLength: return "clock"
        case .cardio: return "figure.run"
        case .periodization: return "chart.line.uptrend.xyaxis"
        case .intensity: return "bolt.fill"
        case .progression: return "arrow.up.forward"
        case .deload: return "leaf.fill"
        }
    }
}

enum CoachRecommendationConfidence: String, Sendable, Equatable, Codable {
    case high
    case medium
    case low
}

struct CoachRecommendation: Identifiable, Equatable, Sendable {
    let id: UUID
    let topic: CoachRecommendationTopic
    var recommendedValue: String
    var finalValue: String
    var rationale: String
    var confidence: CoachRecommendationConfidence
    var isAccepted: Bool
    var isAdjustable: Bool

    init(
        id: UUID = UUID(),
        topic: CoachRecommendationTopic,
        recommendedValue: String,
        finalValue: String? = nil,
        rationale: String,
        confidence: CoachRecommendationConfidence = .high,
        isAccepted: Bool = false,
        isAdjustable: Bool = true
    ) {
        self.id = id
        self.topic = topic
        self.recommendedValue = recommendedValue
        self.finalValue = finalValue ?? recommendedValue
        self.rationale = rationale
        self.confidence = confidence
        self.isAccepted = isAccepted
        self.isAdjustable = isAdjustable
    }

    var userChangedFromRecommendation: Bool {
        recommendedValue != finalValue
    }
}

struct CoachRecommendationChange: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let topic: CoachRecommendationTopic
    let beforeValue: String
    let afterValue: String

    init(
        id: UUID = UUID(),
        topic: CoachRecommendationTopic,
        beforeValue: String,
        afterValue: String
    ) {
        self.id = id
        self.topic = topic
        self.beforeValue = beforeValue
        self.afterValue = afterValue
    }

    var diffDescription: String {
        "\(topic.title) changed from \(beforeValue) to \(afterValue)"
    }
}

// MARK: - Blueprint

/// Complete confirmed plan before mapping into `DynamicProgramGenerationRequest`.
struct CoachBlueprint: Equatable, Sendable {
    var programName: String
    var sessionsPerWeek: Int
    var preferredWeekdays: [Int]
    var primaryGoal: String
    var equipment: String
    var experienceLevel: String
    var splitPreference: String
    var totalWeeks: Int
    var isPeriodized: Bool
    var blockSpecs: [DynamicBlockGenerationSpec]
    var cardioConfiguration: CardioProgramConfiguration
    var intensityStyle: String
    var progressionStyle: String
    var deloadPreference: String
    var busyDayPolicy: BusyDayPolicy
    var limitationsNotes: String
    var additionalNotes: String
    var sessionDurationMinutes: Int?
    var priorityMusclesOrLiftsNotes: String
    var recoveryContextNotes: String
    /// True when the saved split preference was used as a compatible tiebreaker.
    var usedSavedSplitPreference: Bool
    var recommendations: [CoachRecommendation]
    var warnings: [String]
    var changes: [CoachRecommendationChange]

    func recommendation(for topic: CoachRecommendationTopic) -> CoachRecommendation? {
        recommendations.first { $0.topic == topic }
    }

    /// Maps the confirmed blueprint into the existing generation request shape.
    func toGenerationRequest() -> DynamicProgramGenerationRequest {
        let programming = CoachGoalProgramming.resolve(from: primaryGoal, experienceLevel: experienceLevel)
        var splitInput = WorkoutSplitBuilderStructuredInput(
            primaryGoal: primaryGoal,
            equipment: equipment,
            splitPreference: splitPreference,
            experienceLevel: experienceLevel,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            limitationsNotes: limitationsNotes,
            additionalNotes: additionalNotes,
            sessionDurationMinutes: sessionDurationMinutes,
            intensityStyle: intensityStyle,
            progressionStyle: progressionStyle,
            priorityMusclesOrLiftsNotes: priorityMusclesOrLiftsNotes,
            recoveryContextNotes: recoveryContextNotes,
            deloadPreference: deloadPreference,
            variationMode: "Balanced variation",
            desiredWorkoutRotationLength: nil,
            variationNotes: "",
            adjustmentInstruction: nil,
            goalProgrammingDirective: programming.programmingDirective
        )
        splitInput.cardioPreference = cardioConfiguration.preference.rawValue
        splitInput.cardioGoal = cardioConfiguration.goal.rawValue
        splitInput.cardioDedicatedDayCount = cardioConfiguration.dedicatedDayCount
        splitInput.cardioFinisherDurationMinutes = cardioConfiguration.finisherDurationMinutes
        splitInput.cardioFinisherZoneRaw = cardioConfiguration.finisherZone.rawValue
        splitInput.cardioWeeklyProgressionMinutes = cardioConfiguration.weeklyProgressionMinutes

        return DynamicProgramGenerationRequest(
            splitInput: splitInput,
            programName: programName,
            isPeriodized: isPeriodized,
            blockSpecs: blockSpecs,
            busyDayPolicy: busyDayPolicy
        )
    }
}

// MARK: - Discuss threads

enum CoachDiscussMessageRole: String, Sendable, Equatable {
    case coach
    case user
    case system
}

enum CoachDiscussMessageKind: Equatable, Sendable {
    case text(String)
    case typing
    case suggestions([CoachFollowUpSuggestedChange])
}

struct CoachDiscussMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: CoachDiscussMessageRole
    let kind: CoachDiscussMessageKind
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: CoachDiscussMessageRole,
        kind: CoachDiscussMessageKind,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.timestamp = timestamp
    }

    var displayText: String? {
        switch kind {
        case .text(let text): return text
        case .typing: return nil
        case .suggestions: return nil
        }
    }
}

struct CoachDiscussThread: Equatable, Sendable {
    var topic: CoachRecommendationTopic
    var messages: [CoachDiscussMessage]
    var pendingSuggestions: [CoachFollowUpSuggestedChange]
    var isThinking: Bool
    var lastUpdatedAt: Date
    var hasUnreadCoachReply: Bool

    init(
        topic: CoachRecommendationTopic,
        messages: [CoachDiscussMessage] = [],
        pendingSuggestions: [CoachFollowUpSuggestedChange] = [],
        isThinking: Bool = false,
        lastUpdatedAt: Date = Date(),
        hasUnreadCoachReply: Bool = false
    ) {
        self.topic = topic
        self.messages = messages
        self.pendingSuggestions = pendingSuggestions
        self.isThinking = isThinking
        self.lastUpdatedAt = lastUpdatedAt
        self.hasUnreadCoachReply = hasUnreadCoachReply
    }

    var hasDiscussion: Bool {
        !messages.isEmpty
    }

    var latestCoachSummary: String? {
        messages.reversed().first(where: { $0.role == .coach && $0.displayText != nil })?.displayText
    }

    /// Visible messages excluding typing placeholder when not thinking.
    var visibleMessages: [CoachDiscussMessage] {
        messages.filter { message in
            if case .typing = message.kind { return isThinking }
            return true
        }
    }
}

// MARK: - Messages

enum CoachMessageKind: Equatable, Sendable {
    case trainerText(String)
    case userReply(String)
    case phaseDivider(String)
    case intakePrompt(CoachIntakeTopic)
    case changeSummary([CoachRecommendationChange])
    case planPreview
    case typingIndicator
}

struct CoachMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: CoachMessageKind
    let timestamp: Date

    init(id: UUID = UUID(), kind: CoachMessageKind, timestamp: Date = Date()) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
    }
}

// MARK: - AI response payloads

struct CoachRecommendationExplanation: Codable, Equatable, Sendable {
    var topic: String
    var rationale: String
    var tradeoffs: [String]

    var resolvedTopic: CoachRecommendationTopic? {
        CoachRecommendationTopic(rawValue: topic)
            ?? CoachRecommendationTopic.allCases.first { $0.title.lowercased() == topic.lowercased() }
    }
}

struct CoachRecommendationExplanationResponse: Codable, Equatable, Sendable {
    var summary: String
    var recommendations: [CoachRecommendationExplanation]
    var warnings: [String]
}

struct CoachFollowUpSuggestedChange: Codable, Equatable, Sendable {
    var topic: String
    var suggestedValue: String

    var resolvedTopic: CoachRecommendationTopic? {
        CoachRecommendationTopic(rawValue: topic)
            ?? CoachRecommendationTopic.allCases.first { $0.title.lowercased() == topic.lowercased() }
    }
}

struct CoachFollowUpResponse: Codable, Equatable, Sendable {
    var answer: String
    var suggestedChanges: [CoachFollowUpSuggestedChange]
    var requiresUserConfirmation: Bool
}

// MARK: - Intake pickers (shared with wizard)

enum CoachGoalPick: String, CaseIterable, Identifiable, Sendable {
    case buildMuscle = "Build muscle & size"
    case strength = "Get stronger (strength focus)"
    case fatLoss = "Fat loss / conditioning"
    case general = "General fitness & health"
    case performance = "Athletic / sport performance"
    var id: String { rawValue }
}

enum CoachEquipmentPick: String, CaseIterable, Identifiable, Sendable {
    case fullGym = "Full gym (machines + free weights)"
    case homeFreeWeights = "Home — barbell, dumbbells, bench"
    case dumbbellsOnly = "Home — dumbbells only"
    case bodyweight = "Mostly bodyweight"
    case minimal = "Very limited equipment"
    var id: String { rawValue }
}

enum CoachExperiencePick: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

enum CoachSplitPick: String, CaseIterable, Identifiable, Sendable {
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push / Pull / Legs"
    case fullBody = "Full body"
    case broSplit = "Muscle group (bro) split"
    var id: String { rawValue }
}

enum CoachProgramLengthPick: Int, CaseIterable, Identifiable, Sendable {
    case four = 4
    case six = 6
    case eight = 8
    case ten = 10
    case twelve = 12
    case sixteen = 16
    var id: Int { rawValue }
    var label: String { "\(rawValue) weeks" }
}

enum CoachCardioPick: String, CaseIterable, Identifiable, Sendable {
    case none = "None — strength only"
    case postWorkout = "Light finishers after lifting"
    case dedicatedDays = "Dedicated cardio days"
    case mixed = "Mixed (dedicated + finishers)"
    var id: String { rawValue }

    var preference: CardioProgramPreference {
        switch self {
        case .none: return .none
        case .postWorkout: return .postWorkout
        case .dedicatedDays: return .dedicatedDays
        case .mixed: return .mixed
        }
    }
}

enum CoachIntensityPick: String, CaseIterable, Identifiable, Sendable {
    case hypertrophy = "Moderate-heavy hypertrophy (RPE ~7–9)"
    case heavier = "Heavier loads, lower reps"
    case athletic = "Athletic mix — power + strength + conditioning"
    case moderate = "Moderate loads, controlled reps (RPE ~7–8)"
    case balanced = "Balanced (mix of heavy and moderate)"
    var id: String { rawValue }
}

enum CoachProgressionPick: String, CaseIterable, Identifiable, Sendable {
    case linear = "Linear / add weight when form is solid"
    case doubleProgression = "Double progression (reps then weight)"
    case linearMains = "Linear on main lifts; double progression on accessories"
    var id: String { rawValue }
}

enum CoachDeloadPick: String, CaseIterable, Identifiable, Sendable {
    case everyFourth = "Lighter week about every 4th week"
    case asNeeded = "Deload when I feel run-down"
    var id: String { rawValue }
}

enum CoachSessionDurationPick: String, CaseIterable, Identifiable, Sendable {
    case thirty = "~30 minutes per session"
    case fortyFive = "~45 minutes per session"
    case sixty = "~60 minutes per session"
    case seventyFive = "~75 minutes per session"
    case ninetyPlus = "~90+ minutes per session"
    var id: String { rawValue }

    var minutes: Int? {
        SessionDurationBuckets.minutes(fromPickerLabel: rawValue)
    }
}

// MARK: - Entry route preference

enum ProgramBuilderEntryRoute: String, Sendable, Equatable {
    case guidedCoach
    case templates
    case advancedBuilder
}
