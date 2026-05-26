//
//  ExerciseFormGuideModelsTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ExerciseFormGuideModelsTests {

    @Test func bestVideo_prefersExactGenderAndAngleMatch() {
        let guide = ExerciseFormGuide(
            fitLogExerciseId: UUID(),
            title: "Squat",
            steps: [],
            videos: [
                makeVideo(gender: .male, angle: .front, id: "male-front"),
                makeVideo(gender: .male, angle: .side, id: "male-side"),
                makeVideo(gender: .female, angle: .front, id: "female-front")
            ],
            keyCue: nil
        )

        #expect(guide.bestVideo(gender: .male, angle: .side)?.id == "male-side")
    }

    @Test func bestVideo_fallsBackToGenderThenAnyVideo() {
        let guide = ExerciseFormGuide(
            fitLogExerciseId: UUID(),
            title: "Press",
            steps: [],
            videos: [
                makeVideo(gender: .male, angle: .front, id: "male-front"),
                makeVideo(gender: .female, angle: .side, id: "female-side")
            ],
            keyCue: nil
        )

        #expect(guide.bestVideo(gender: .female, angle: .front)?.id == "female-side")
        #expect(guide.bestVideo(gender: .female, angle: .side)?.id == "female-side")
    }

    private func makeVideo(gender: FormGuideGender, angle: FormGuideAngle, id: String) -> ExerciseFormGuideVideo {
        ExerciseFormGuideVideo(
            id: id,
            streamURL: URL(string: "https://example.com/\(id).mp4")!,
            gender: gender,
            angle: angle,
            ogImageURL: URL(string: "https://example.com/\(id).jpg")
        )
    }
}
