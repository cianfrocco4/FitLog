//
//  FoundationModelsClient.swift
//  FitLog
//
//  Thin wrapper around Apple Foundation Models (iOS 26+).
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class FoundationModelsClient: OnDeviceLanguageModel {
    static let shared = FoundationModelsClient()

    var availability: OnDeviceAIAvailability {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable(reason: "This device does not support Apple Intelligence.")
                case .appleIntelligenceNotEnabled:
                    return .unavailable(reason: "Turn on Apple Intelligence in Settings to use on-device coaching.")
                case .modelNotReady:
                    return .unavailable(reason: "Apple Intelligence is still downloading. Using cloud AI when available.")
                @unknown default:
                    return .unavailable(reason: "On-device AI is unavailable right now.")
                }
            }
        }
#endif
        return .unavailable(reason: "On-device AI requires iOS 26 with Apple Intelligence.")
    }

    func generateDailyAdjustment(context: DailyAdjustContextPack) async throws -> DailyAdjustmentProposal {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try requireAvailable()
            let session = LanguageModelSession {
                """
                You are a strength coach inside Workout Log AI. Suggest a conservative adjustment \
                for today's training only. Prefer reducing volume or rest when readiness is low. \
                Never claim medical diagnosis. Always set disclaimerAck to true. \
                Use change kinds exactly: makeLighter, markRest, keepAsPlanned, swapFocusNote.
                """
            }
            let prompt = """
            Day: \(context.dayKey)
            Readiness: \(context.readinessScore.map(String.init) ?? "unknown") — \(context.readinessSummary)
            Planned workout: \(context.plannedWorkoutName) — \(context.plannedWorkoutDetail)
            Recent load: \(context.recentLoadSummary)
            Athlete note: \(context.userNote.isEmpty ? "(none)" : context.userNote)
            Has dynamic program busy-day support: \(context.hasDynamicProgram)
            """
            let response = try await session.respond(to: prompt, generating: GenerableDailyAdjustment.self)
            return GenerableMapping.dailyAdjustment(from: response.content)
        }
#endif
        throw OnDeviceAIError.unavailable
    }

    func generateWeeklyInsight(weekKey: String, contextText: String) async throws -> WeeklyInsight {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try requireAvailable()
            let session = LanguageModelSession {
                """
                You are a strength coach summarizing one training week for Workout Log AI. \
                Be concise, encouraging, and practical. Not medical advice.
                """
            }
            let response = try await session.respond(to: contextText, generating: GenerableWeeklyInsight.self)
            return GenerableMapping.weeklyInsight(from: response.content, weekKey: weekKey)
        }
#endif
        throw OnDeviceAIError.unavailable
    }

    func rankSubstitutions(prompt: String) async throws -> [ExerciseSubstitutionCandidate] {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try requireAvailable()
            let session = LanguageModelSession {
                """
                Rank exercise substitutions. Only use exercise names from the provided library list. \
                Prefer same primary muscles and similar equipment.
                """
            }
            let response = try await session.respond(to: prompt, generating: GenerableSubstitutionList.self)
            return response.content.items.map {
                ExerciseSubstitutionCandidate(id: UUID(), exerciseName: $0.exerciseName, rationale: $0.rationale)
            }
        }
#endif
        throw OnDeviceAIError.unavailable
    }

    func generateFormCues(prompt: String) async throws -> [String] {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try requireAvailable()
            let session = LanguageModelSession {
                "Give short, actionable lifting form cues. Not medical advice. Max 4 cues."
            }
            let response = try await session.respond(to: prompt, generating: GenerableFormCues.self)
            return Array(response.content.cues.prefix(4))
        }
#endif
        throw OnDeviceAIError.unavailable
    }

    func shortCoachReply(system: String, user: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try requireAvailable()
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            return response.content
        }
#endif
        throw OnDeviceAIError.unavailable
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func requireAvailable() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw OnDeviceAIError.unavailable
        }
    }
#endif
}
