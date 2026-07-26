//
//  OnDeviceLanguageModel.swift
//  FitLog
//
//  Protocol seam for on-device language generation (testable without Apple Intelligence).
//

import Foundation

@MainActor
protocol OnDeviceLanguageModel: AnyObject {
    var availability: OnDeviceAIAvailability { get }
    func generateDailyAdjustment(context: DailyAdjustContextPack) async throws -> DailyAdjustmentProposal
    func generateWeeklyInsight(weekKey: String, contextText: String) async throws -> WeeklyInsight
    func rankSubstitutions(prompt: String) async throws -> [ExerciseSubstitutionCandidate]
    func generateFormCues(prompt: String) async throws -> [String]
    func shortCoachReply(system: String, user: String) async throws -> String
}

enum OnDeviceAIError: LocalizedError {
    case unavailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device Apple Intelligence is not available on this device."
        case .generationFailed(let message):
            return message
        }
    }
}
