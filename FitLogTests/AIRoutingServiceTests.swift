//
//  AIRoutingServiceTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@MainActor
private final class FakeOnDeviceModel: OnDeviceLanguageModel {
    var availability: OnDeviceAIAvailability
    var shouldFail = false

    init(availability: OnDeviceAIAvailability) {
        self.availability = availability
    }

    func generateDailyAdjustment(context: DailyAdjustContextPack) async throws -> DailyAdjustmentProposal {
        if shouldFail { throw OnDeviceAIError.generationFailed("boom") }
        return DailyAdjustmentProposal(
            summary: "On-device",
            changes: [DailyAdjustmentChange(kind: .keepAsPlanned, detail: "OK")],
            rationale: "Test",
            disclaimerAck: true,
            routeUsed: .onDevice
        )
    }

    func generateWeeklyInsight(weekKey: String, contextText: String) async throws -> WeeklyInsight {
        if shouldFail { throw OnDeviceAIError.generationFailed("boom") }
        return WeeklyInsight(
            weekKey: weekKey,
            title: "On-device week",
            narrative: "Narrative",
            highlights: ["H"],
            risks: [],
            nextActions: ["A"],
            routeUsed: .onDevice,
            generatedAt: .now
        )
    }

    func rankSubstitutions(prompt: String) async throws -> [ExerciseSubstitutionCandidate] {
        []
    }

    func generateFormCues(prompt: String) async throws -> [String] {
        ["Brace"]
    }

    func shortCoachReply(system: String, user: String) async throws -> String {
        "On-device reply"
    }
}

struct AIRoutingServiceTests {
    private func sampleContext(hasDynamic: Bool = true) -> DailyAdjustContextPack {
        DailyAdjustContextPack(
            dayKey: "2026-07-26",
            readinessScore: 40,
            readinessSummary: "Low",
            plannedWorkoutName: "Push",
            plannedWorkoutDetail: "Bench, OHP",
            recentLoadSummary: "high",
            userNote: "shoulders sore",
            hasDynamicProgram: hasDynamic
        )
    }

    @Test @MainActor func proposeDailyAdjustment_prefersOnDeviceWhenAvailable() async {
        let fake = FakeOnDeviceModel(availability: .available)
        let router = AIRoutingService(onDeviceModel: fake)
        let proposal = await router.proposeDailyAdjustment(
            context: sampleContext(),
            isPremium: true,
            aiService: AIService(apiKey: nil, baseURL: nil)
        )
        #expect(proposal.routeUsed == .onDevice)
        #expect(proposal.summary == "On-device")
    }

    @Test @MainActor func proposeDailyAdjustment_fallsBackToHeuristicWhenUnavailable() async {
        let fake = FakeOnDeviceModel(availability: .unavailable(reason: "no AI"))
        let router = AIRoutingService(onDeviceModel: fake)
        let proposal = await router.proposeDailyAdjustment(
            context: sampleContext(),
            isPremium: true,
            aiService: AIService(apiKey: nil, baseURL: nil)
        )
        #expect(proposal.routeUsed == .heuristic)
        #expect(proposal.changes.contains(where: { $0.kind == .makeLighter || $0.kind == .markRest }))
    }

    @Test func parseDailyAdjustmentJSON_extractsPayload() {
        let raw = """
        Here you go:
        {"summary":"Go lighter","changes":[{"kind":"makeLighter","detail":"Busy day"}],"rationale":"Low readiness","disclaimerAck":true}
        """
        let parsed = AIRoutingService.parseDailyAdjustmentJSON(raw)
        #expect(parsed?.summary == "Go lighter")
        #expect(parsed?.changes.first?.kind == .makeLighter)
        #expect(parsed?.routeUsed == .cloud)
    }

    @Test func heuristics_lowReadinessSuggestsLighterOrRest() {
        let proposal = DailyAdjustHeuristics.proposal(for: DailyAdjustContextPack(
            dayKey: "2026-07-26",
            readinessScore: 30,
            readinessSummary: "Low",
            plannedWorkoutName: "Legs",
            plannedWorkoutDetail: "Squat",
            recentLoadSummary: "high",
            userNote: "",
            hasDynamicProgram: true
        ))
        #expect(proposal.routeUsed == .heuristic)
        #expect(proposal.changes.contains(where: { $0.kind == .makeLighter }))
    }

    @Test func exerciseSubstitution_filtersBySharedMuscles() {
        let source = Exercise(
            id: UUID(),
            name: "Bench Press",
            description: "",
            targetedMuscles: [.chest, .triceps]
        )
        let match = Exercise(
            id: UUID(),
            name: "DB Bench",
            description: "",
            targetedMuscles: [.chest]
        )
        let other = Exercise(
            id: UUID(),
            name: "Curl",
            description: "",
            targetedMuscles: [.biceps]
        )
        let result = ExerciseSubstitutionService.candidates(for: source, in: [match, other, source])
        #expect(result.map(\.name) == ["DB Bench"])
    }

    @Test func weeklyInsightCache_roundTrip() {
        let key = "2099-W01"
        let insight = WeeklyInsight(
            weekKey: key,
            title: "Test",
            narrative: "N",
            highlights: ["H"],
            risks: [],
            nextActions: ["A"],
            routeUsed: .heuristic,
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let defaults = UserDefaults(suiteName: "fitlog.tests.weeklyInsight")!
        defaults.removePersistentDomain(forName: "fitlog.tests.weeklyInsight")
        WeeklyInsightCache.save(insight, defaults: defaults)
        let loaded = WeeklyInsightCache.load(weekKey: key, defaults: defaults)
        #expect(loaded?.title == "Test")
        #expect(loaded?.weekKey == key)
    }
}
