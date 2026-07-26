//
//  AIRoutingService.swift
//  FitLog
//
//  Premium AI router: on-device preferred → cloud → heuristic.
//

import Foundation
import Observation

@Observable @MainActor
final class AIRoutingService {
    static let shared = AIRoutingService()

    private(set) var lastRoute: AIRouteUsed?
    var onDeviceModel: any OnDeviceLanguageModel

    init(onDeviceModel: (any OnDeviceLanguageModel)? = nil) {
        self.onDeviceModel = onDeviceModel ?? FoundationModelsClient.shared
    }

    var onDeviceAvailability: OnDeviceAIAvailability {
        onDeviceModel.availability
    }

    var availabilityBannerText: String? {
        switch onDeviceAvailability {
        case .available:
            return nil
        case .unavailable(let reason):
            return reason
        }
    }

    func proposeDailyAdjustment(
        context: DailyAdjustContextPack,
        isPremium: Bool,
        aiService: AIService
    ) async -> DailyAdjustmentProposal {
        guard isPremium else {
            AnalyticsService.shared.track(.aiBlockedByPaywall, properties: ["feature": "daily_adjust"])
            return DailyAdjustHeuristics.proposal(for: context)
        }

        if onDeviceAvailability.isAvailable {
            do {
                let proposal = try await onDeviceModel.generateDailyAdjustment(context: context)
                lastRoute = .onDevice
                AnalyticsService.shared.track(.onDeviceAIUsed, properties: ["feature": "daily_adjust"])
                return proposal
            } catch {
                AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                    "feature": "daily_adjust",
                    "reason": error.localizedDescription
                ])
            }
        } else {
            AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                "feature": "daily_adjust",
                "reason": onDeviceAvailability.userFacingMessage
            ])
        }

        if aiService.isConfigured {
            if let cloud = await cloudDailyAdjustment(context: context, aiService: aiService) {
                lastRoute = .cloud
                AnalyticsService.shared.track(.aiRoutedCloudFallback, properties: ["feature": "daily_adjust"])
                return cloud
            }
        }

        lastRoute = .heuristic
        AnalyticsService.shared.track(.aiRoutedCloudFallback, properties: [
            "feature": "daily_adjust",
            "reason": "heuristic"
        ])
        return DailyAdjustHeuristics.proposal(for: context)
    }

    func proposeWeeklyInsight(
        weekKey: String,
        contextText: String,
        isPremium: Bool,
        aiService: AIService
    ) async -> WeeklyInsight {
        guard isPremium else {
            return Self.placeholderInsight(weekKey: weekKey, route: .heuristic)
        }

        if onDeviceAvailability.isAvailable {
            do {
                let insight = try await onDeviceModel.generateWeeklyInsight(weekKey: weekKey, contextText: contextText)
                lastRoute = .onDevice
                AnalyticsService.shared.track(.onDeviceAIUsed, properties: ["feature": "weekly_insight"])
                return insight
            } catch {
                AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                    "feature": "weekly_insight",
                    "reason": error.localizedDescription
                ])
            }
        }

        if aiService.isConfigured {
            if let cloud = await cloudWeeklyInsight(weekKey: weekKey, contextText: contextText, aiService: aiService) {
                lastRoute = .cloud
                AnalyticsService.shared.track(.aiRoutedCloudFallback, properties: ["feature": "weekly_insight"])
                return cloud
            }
        }

        lastRoute = .heuristic
        return Self.heuristicInsight(weekKey: weekKey, contextText: contextText)
    }

    func shortCoachReply(
        system: String,
        user: String,
        isPremium: Bool,
        preferOnDevice: Bool,
        aiService: AIService,
        cloudFallback: () async throws -> String
    ) async throws -> (text: String, route: AIRouteUsed) {
        guard isPremium else { throw OnDeviceAIError.unavailable }

        if preferOnDevice, onDeviceAvailability.isAvailable, user.count <= 400 {
            do {
                let text = try await onDeviceModel.shortCoachReply(system: system, user: user)
                lastRoute = .onDevice
                AnalyticsService.shared.track(.onDeviceAIUsed, properties: ["feature": "coach_short"])
                return (text, .onDevice)
            } catch {
                AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                    "feature": "coach_short",
                    "reason": error.localizedDescription
                ])
            }
        }

        let text = try await cloudFallback()
        lastRoute = .cloud
        AnalyticsService.shared.track(.aiRoutedCloudFallback, properties: ["feature": "coach_short"])
        return (text, .cloud)
    }

    func formCues(
        exerciseName: String,
        isPremium: Bool,
        aiService: AIService,
        cloudFallback: () async throws -> [String]
    ) async -> FormCueResult {
        guard isPremium else {
            return FormCueResult(cues: Self.defaultFormCues(for: exerciseName), routeUsed: .heuristic)
        }

        if onDeviceAvailability.isAvailable {
            do {
                let cues = try await onDeviceModel.generateFormCues(
                    prompt: "Exercise: \(exerciseName). Give 2-4 short form cues."
                )
                if !cues.isEmpty {
                    AnalyticsService.shared.track(.onDeviceAIUsed, properties: ["feature": "form_cues"])
                    return FormCueResult(cues: cues, routeUsed: .onDevice)
                }
            } catch {
                AnalyticsService.shared.track(.onDeviceAIUnavailable, properties: [
                    "feature": "form_cues",
                    "reason": error.localizedDescription
                ])
            }
        }

        if aiService.isConfigured {
            do {
                let cues = try await cloudFallback()
                if !cues.isEmpty {
                    AnalyticsService.shared.track(.aiRoutedCloudFallback, properties: ["feature": "form_cues"])
                    return FormCueResult(cues: cues, routeUsed: .cloud)
                }
            } catch { /* fall through */ }
        }

        return FormCueResult(cues: Self.defaultFormCues(for: exerciseName), routeUsed: .heuristic)
    }

    // MARK: - Cloud helpers

    private func cloudDailyAdjustment(context: DailyAdjustContextPack, aiService: AIService) async -> DailyAdjustmentProposal? {
        let system = """
        Return ONLY JSON matching:
        {"summary":"","changes":[{"kind":"makeLighter|markRest|keepAsPlanned|swapFocusNote","detail":""}],"rationale":"","disclaimerAck":true}
        General fitness coaching only — not medical advice.
        """
        let user = """
        Readiness \(context.readinessScore.map(String.init) ?? "?"): \(context.readinessSummary)
        Plan: \(context.plannedWorkoutName) — \(context.plannedWorkoutDetail)
        Load: \(context.recentLoadSummary)
        Note: \(context.userNote)
        Dynamic busy-day available: \(context.hasDynamicProgram)
        """
        do {
            let raw = try await aiService.coachChat(
                conversation: [(role: "user", content: system + "\n\n" + user)],
                contextSnapshot: ""
            )
            return Self.parseDailyAdjustmentJSON(raw)
        } catch {
            return nil
        }
    }

    private func cloudWeeklyInsight(weekKey: String, contextText: String, aiService: AIService) async -> WeeklyInsight? {
        let prompt = """
        Return ONLY JSON:
        {"title":"","narrative":"","highlights":[],"risks":[],"nextActions":[]}
        Not medical advice.

        \(contextText)
        """
        do {
            let raw = try await aiService.coachChat(
                conversation: [(role: "user", content: prompt)],
                contextSnapshot: ""
            )
            return Self.parseWeeklyInsightJSON(raw, weekKey: weekKey)
        } catch {
            return nil
        }
    }

    // MARK: - Parsing / placeholders

    nonisolated static func parseDailyAdjustmentJSON(_ raw: String) -> DailyAdjustmentProposal? {
        struct Payload: Decodable {
            var summary: String
            var changes: [Change]
            var rationale: String
            var disclaimerAck: Bool?
            struct Change: Decodable {
                var kind: String
                var detail: String
            }
        }
        guard let data = extractJSONObject(from: raw)?.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        let changes = payload.changes.compactMap { c -> DailyAdjustmentChange? in
            guard let kind = DailyAdjustActionKind(rawValue: c.kind) else { return nil }
            return DailyAdjustmentChange(kind: kind, detail: c.detail)
        }
        return DailyAdjustmentProposal(
            summary: payload.summary,
            changes: changes.isEmpty
                ? [DailyAdjustmentChange(kind: .keepAsPlanned, detail: "Keep today's plan.")]
                : changes,
            rationale: payload.rationale,
            disclaimerAck: payload.disclaimerAck ?? true,
            routeUsed: .cloud
        )
    }

    nonisolated static func parseWeeklyInsightJSON(_ raw: String, weekKey: String) -> WeeklyInsight? {
        struct Payload: Decodable {
            var title: String
            var narrative: String
            var highlights: [String]
            var risks: [String]
            var nextActions: [String]
        }
        guard let data = extractJSONObject(from: raw)?.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return WeeklyInsight(
            weekKey: weekKey,
            title: payload.title,
            narrative: payload.narrative,
            highlights: payload.highlights,
            risks: payload.risks,
            nextActions: payload.nextActions,
            routeUsed: .cloud,
            generatedAt: .now
        )
    }

    nonisolated static func extractJSONObject(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return trimmed }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else { return nil }
        return String(trimmed[start...end])
    }

    nonisolated static func placeholderInsight(weekKey: String, route: AIRouteUsed) -> WeeklyInsight {
        WeeklyInsight(
            weekKey: weekKey,
            title: "Week in review",
            narrative: "Upgrade to Premium for a natural-language summary of your training and readiness.",
            highlights: [],
            risks: [],
            nextActions: ["Log consistently", "Check readiness on Home"],
            routeUsed: route,
            generatedAt: .now
        )
    }

    nonisolated static func heuristicInsight(weekKey: String, contextText: String) -> WeeklyInsight {
        let sessionHint = contextText.localizedCaseInsensitiveContains("sessions") ? "You trained this week." : "Keep logging sessions for richer insights."
        return WeeklyInsight(
            weekKey: weekKey,
            title: "Week in review",
            narrative: "\(sessionHint) Focus on recovery and progressive overload next week. Not medical advice.",
            highlights: ["Consistency beats perfection"],
            risks: ["Watch for accumulated fatigue if readiness trends down"],
            nextActions: ["Protect sleep", "Progress one main lift", "Keep one easier day"],
            routeUsed: .heuristic,
            generatedAt: .now
        )
    }

    nonisolated static func defaultFormCues(for exerciseName: String) -> [String] {
        [
            "Brace your core before the lift.",
            "Control the eccentric; avoid bouncing.",
            "Stop the set if form breaks down.",
            "\(exerciseName): keep joints stacked and path smooth."
        ]
    }
}
