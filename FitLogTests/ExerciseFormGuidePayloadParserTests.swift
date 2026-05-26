//
//  ExerciseFormGuidePayloadParserTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ExerciseFormGuidePayloadParserTests {

    private let directStreamBase = URL(string: "https://api.musclewiki.com/stream/videos/branded")!
    private let proxyStreamBase = URL(string: "https://the-workout-log.onrender.com/v1/form-guide/stream/videos/branded")!

    @Test func makeGuide_returnsNilWhenVideosAndStepsAreEmpty() {
        let exercise = Exercise(
            id: UUID(),
            name: "Mystery Move",
            description: "",
            targetedMuscles: [.chest]
        )
        let payload = MuscleWikiExercisePayload(
            id: 1,
            name: "Mystery Move",
            steps: [],
            videos: []
        )

        #expect(ExerciseFormGuidePayloadParser.makeGuide(from: payload, exercise: exercise) == nil)
    }

    @Test func makeGuide_buildsVideosFromStepsOnlyPayload() {
        let exerciseId = UUID()
        let exercise = Exercise(
            id: exerciseId,
            name: "Plank",
            description: "",
            targetedMuscles: [.abs]
        )
        let payload = MuscleWikiExercisePayload(
            id: 2,
            name: "Plank",
            steps: ["Brace your core", "Hold a straight line"],
            videos: nil
        )

        let guide = ExerciseFormGuidePayloadParser.makeGuide(from: payload, exercise: exercise)
        #expect(guide?.fitLogExerciseId == exerciseId)
        #expect(guide?.steps.count == 2)
        #expect(guide?.videos.isEmpty == true)
        #expect(guide?.keyCue == "Brace your core")
    }

    @Test func resolveStreamURL_usesBrandedStreamPathForBareFilename() {
        let video = MuscleWikiVideoPayload(
            gender: "male",
            angle: "front",
            url: nil,
            filename: "bench-press.mp4",
            file: nil,
            ogImageURL: "https://example.com/bench.jpg"
        )

        let url = ExerciseFormGuidePayloadParser.resolveStreamURL(from: video, streamBaseURL: directStreamBase)
        #expect(url?.absoluteString == "https://api.musclewiki.com/stream/videos/branded/bench-press.mp4")
    }

    @Test func resolveStreamURL_rewritesMuscleWikiURLToProxyBase() {
        let video = MuscleWikiVideoPayload(
            gender: "male",
            angle: "front",
            url: "https://api.musclewiki.com/stream/videos/branded/squat.mp4",
            filename: nil,
            file: nil,
            ogImageURL: nil
        )

        let url = ExerciseFormGuidePayloadParser.resolveStreamURL(from: video, streamBaseURL: proxyStreamBase)
        #expect(url?.absoluteString == "https://the-workout-log.onrender.com/v1/form-guide/stream/videos/branded/squat.mp4")
    }

    @Test func resolveStreamURL_buildsStreamPathFromMP4URL() {
        let video = MuscleWikiVideoPayload(
            gender: "female",
            angle: "side",
            url: "https://cdn.example.com/deadlift.mp4",
            filename: nil,
            file: nil,
            ogImageURL: nil
        )

        let url = ExerciseFormGuidePayloadParser.resolveStreamURL(from: video, streamBaseURL: directStreamBase)
        #expect(url?.lastPathComponent == "deadlift.mp4")
        #expect(url?.absoluteString == "https://api.musclewiki.com/stream/videos/branded/deadlift.mp4")
    }

    @Test func brandedStreamFilename_extractsFromStreamPath() {
        let video = MuscleWikiVideoPayload(
            gender: "male",
            angle: "front",
            url: "https://api.musclewiki.com/stream/videos/branded/lunge.mp4",
            filename: nil,
            file: nil,
            ogImageURL: nil
        )

        #expect(ExerciseFormGuidePayloadParser.brandedStreamFilename(from: video) == "lunge.mp4")
    }

    @Test func decodeSearchResults_parsesTopLevelJSONArray() throws {
        let json = """
        [{
            "id": 4,
            "name": "Barbell Bench Press",
            "steps": ["Lower the bar to mid chest"],
            "videos": [{
                "url": "https://api.musclewiki.com/stream/videos/branded/male-barbell-bench-press-front.mp4",
                "angle": "front",
                "gender": "male",
                "og_image": "https://api.musclewiki.com/stream/images/og_images/og-male-barbell-bench-press-front.jpg"
            }]
        }]
        """
        let data = Data(json.utf8)
        let results = try ExerciseFormGuidePayloadParser.decodeSearchResults(from: data)

        #expect(results.count == 1)
        #expect(results[0].id == 4)
        #expect(results[0].name == "Barbell Bench Press")
        #expect(results[0].steps?.first == "Lower the bar to mid chest")
        #expect(results[0].videos?.first?.ogImageURL?.contains("og-male-barbell-bench-press-front.jpg") == true)
    }

    @Test func decodeSearchResults_parsesEnvelopeShape() throws {
        let json = """
        {
            "results": [{
                "id": 7,
                "name": "Barbell Squat",
                "steps": ["Sit back and down"],
                "videos": []
            }]
        }
        """
        let data = Data(json.utf8)
        let results = try ExerciseFormGuidePayloadParser.decodeSearchResults(from: data)

        #expect(results.count == 1)
        #expect(results[0].id == 7)
        #expect(results[0].name == "Barbell Squat")
    }

    @Test func muscleWikiVideoPayload_decodesOgImageURLFromOgImageKey() throws {
        let json = """
        {
            "gender": "male",
            "angle": "front",
            "url": "https://api.musclewiki.com/stream/videos/branded/squat.mp4",
            "og_image": "https://example.com/thumb.jpg"
        }
        """
        let data = Data(json.utf8)
        let video = try JSONDecoder().decode(MuscleWikiVideoPayload.self, from: data)

        #expect(video.ogImageURL == "https://example.com/thumb.jpg")
    }

    @Test func muscleWikiVideoPayload_prefersOgImageURLKeyOverOgImage() throws {
        let json = """
        {
            "gender": "female",
            "angle": "side",
            "og_image_url": "https://example.com/preferred.jpg",
            "og_image": "https://example.com/fallback.jpg"
        }
        """
        let data = Data(json.utf8)
        let video = try JSONDecoder().decode(MuscleWikiVideoPayload.self, from: data)

        #expect(video.ogImageURL == "https://example.com/preferred.jpg")
    }
}
