//
//  ExerciseFormGuideServiceTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@MainActor
struct ExerciseFormGuideServiceTests {

    @Test func guide_whenNotConfigured_setsFailedLoadState() async {
        let service = ExerciseFormGuideService(apiKey: nil, proxyBaseURL: nil)
        let exercise = Exercise(
            id: UUID(),
            name: "Barbell Bench Press",
            description: "",
            targetedMuscles: [.chest]
        )

        let guide = await service.guide(for: exercise)
        #expect(guide == nil)
        if case .failed = service.loadState(for: exercise.id) {
            // expected
        } else {
            Issue.record("Expected failed load state when form guide is not configured")
        }

        let secondFetch = await service.guide(for: exercise)
        #expect(secondFetch == nil)
    }

    @Test func isConfigured_trueWhenOnlyProxyBaseURLSet() {
        let service = ExerciseFormGuideService(apiKey: nil, proxyBaseURL: "https://proxy.example.com")
        #expect(service.isConfigured == true)
    }

    @Test func streamRequestHeaders_proxyMode_sendsSharedSecretAndIgnoresMuscleWikiKey() {
        let service = ExerciseFormGuideService(
            apiKey: "mw-should-be-ignored",
            proxyBaseURL: "https://proxy.example.com",
            proxySharedSecret: "proxy-secret"
        )
        #expect(service.streamRequestHeaders() == [
            FitLogProxyConfig.proxySecretHeaderName: "proxy-secret"
        ])
        #expect(service.streamRequestHeaders()["X-API-Key"] == nil)
    }

    @Test func streamRequestHeaders_proxyModeWithoutSecret_isEmpty() {
        let service = ExerciseFormGuideService(
            apiKey: "mw-should-be-ignored",
            proxyBaseURL: "https://proxy.example.com",
            proxySharedSecret: nil
        )
        #expect(service.streamRequestHeaders().isEmpty)
    }

    @Test func streamRequestHeaders_includesKeyInDirectMode() {
        let service = ExerciseFormGuideService(
            apiKey: "mw-test-key",
            proxyBaseURL: nil,
            proxySharedSecret: "unused"
        )
        #expect(service.streamRequestHeaders()[FitLogProxyConfig.muscleWikiAPIKeyHeaderName] == "mw-test-key")
        #expect(service.streamRequestHeaders()[FitLogProxyConfig.proxySecretHeaderName] == nil)
    }

    @Test func cachedGuide_returnsSeededPreviewGuide() async {
        let exerciseId = UUID()
        let exercise = Exercise(
            id: exerciseId,
            name: "Back Squat (High Bar)",
            description: "",
            targetedMuscles: [.quads]
        )
        let seededGuide = ExerciseFormGuide(
            fitLogExerciseId: exerciseId,
            title: "Barbell Squat",
            steps: ["Brace and sit down."],
            videos: [],
            keyCue: "Brace and sit down."
        )

        let service = ExerciseFormGuideService(apiKey: "preview", proxyBaseURL: nil)
        service.seedPreviewGuide(seededGuide)

        let guide = await service.guide(for: exercise)
        #expect(guide == seededGuide)
        #expect(service.cachedGuide(for: exerciseId) == seededGuide)
    }
}
