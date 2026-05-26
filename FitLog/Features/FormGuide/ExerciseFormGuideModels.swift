//
//  ExerciseFormGuideModels.swift
//  FitLog
//
//  Domain models for exercise form guide content (MuscleWiki videos + AI cues).
//

import Foundation

enum FormGuideGender: String, CaseIterable, Identifiable, Codable, Sendable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum FormGuideAngle: String, CaseIterable, Identifiable, Codable, Sendable {
    case front
    case side

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .front: return "Front"
        case .side: return "Side"
        }
    }
}

struct ExerciseFormGuideVideo: Identifiable, Equatable, Sendable {
    let id: String
    let streamURL: URL
    let gender: FormGuideGender
    let angle: FormGuideAngle
    let ogImageURL: URL?
}

struct ExerciseFormGuide: Equatable, Sendable {
    let fitLogExerciseId: UUID
    let title: String
    let steps: [String]
    let videos: [ExerciseFormGuideVideo]
    let keyCue: String?

    func bestVideo(gender: FormGuideGender, angle: FormGuideAngle) -> ExerciseFormGuideVideo? {
        videos.first { $0.gender == gender && $0.angle == angle }
            ?? videos.first { $0.gender == gender }
            ?? videos.first { $0.angle == angle }
            ?? videos.first
    }
}

enum ExerciseFormGuideLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded(ExerciseFormGuide)
    case unavailable
    case failed(String)
}

struct ExerciseFormGuideMappingEntry: Codable, Sendable {
    let searchQuery: String
    let muscleWikiId: Int?
}

struct ExerciseFormGuideMappingFile: Codable, Sendable {
    let version: Int
    let mappings: [String: ExerciseFormGuideMappingEntry]
}
