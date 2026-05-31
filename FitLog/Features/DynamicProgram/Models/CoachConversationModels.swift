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
    case recommendations
    case review
    case generating
    case complete
}

// MARK: - Intake

enum CoachIntakeTopic: String, CaseIterable, Sendable, Equatable {
    case goal
    case experience
    case schedule
    case equipment
    case constraints
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
    var recommendations: [CoachRecommendation]
    var warnings: [String]
    var changes: [CoachRecommendationChange]

    func recommendation(for topic: CoachRecommendationTopic) -> CoachRecommendation? {
        recommendations.first { $0.topic == topic }
    }

    /// Maps the confirmed blueprint into the existing generation request shape.
    func toGenerationRequest() -> DynamicProgramGenerationRequest {
        var splitInput = WorkoutSplitBuilderStructuredInput(
            primaryGoal: primaryGoal,
            equipment: equipment,
            splitPreference: splitPreference,
            experienceLevel: experienceLevel,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            limitationsNotes: limitationsNotes,
            additionalNotes: additionalNotes,
            sessionDurationMinutes: nil,
            intensityStyle: intensityStyle,
            progressionStyle: progressionStyle,
            priorityMusclesOrLiftsNotes: "",
            recoveryContextNotes: "",
            deloadPreference: deloadPreference,
            variationMode: "Balanced variation",
            desiredWorkoutRotationLength: nil,
            variationNotes: "",
            adjustmentInstruction: nil
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

// MARK: - Messages

enum CoachMessageKind: Equatable, Sendable {
    case trainerText(String)
    case userReply(String)
    case phaseDivider(String)
    case intakePrompt(CoachIntakeTopic)
    case recommendationCards
    case changeSummary([CoachRecommendationChange])
    case blueprintSummary
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
    case eight = 8
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

// MARK: - Entry route preference

enum ProgramBuilderEntryRoute: String, Sendable, Equatable {
    case guidedCoach
    case templates
    case advancedBuilder
}
