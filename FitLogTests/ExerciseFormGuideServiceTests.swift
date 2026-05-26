//
//  ExerciseFormGuideServiceTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@MainActor
struct ExerciseFormGuideServiceTests {

    @Test func guide_whenNotConfigured_marksExerciseUnavailable() async {
        let service = ExerciseFormGuideService(apiKey: nil, proxyBaseURL: nil)
        let exercise = Exercise(
            id: UUID(),
            name: "Barbell Bench Press",
            description: "",
            targetedMuscles: [.chest]
        )

        let guide = await service.guide(for: exercise)
        #expect(guide == nil)
        #expect(service.loadState(for: exercise.id) == .unavailable)

        let secondFetch = await service.guide(for: exercise)
        #expect(secondFetch == nil)
    }

    @Test func isConfigured_trueWhenOnlyProxyBaseURLSet() {
        let service = ExerciseFormGuideService(apiKey: nil, proxyBaseURL: "https://proxy.example.com")
        #expect(service.isConfigured == true)
    }

    @Test func streamRequestHeaders_emptyInProxyMode() {
        let service = ExerciseFormGuideService(apiKey: "mw-should-be-ignored", proxyBaseURL: "https://proxy.example.com")
        #expect(service.streamRequestHeaders().isEmpty)
    }

    @Test func streamRequestHeaders_includesKeyInDirectMode() {
        let service = ExerciseFormGuideService(apiKey: "mw-test-key", proxyBaseURL: nil)
        #expect(service.streamRequestHeaders()["X-API-Key"] == "mw-test-key")
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
