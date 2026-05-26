//
//  ExerciseFormGuidePayloadParser.swift
//  FitLog
//
//  Pure parsing helpers for MuscleWiki API payloads.
//

import Foundation

enum ExerciseFormGuidePayloadParser {
    static func makeGuide(
        from payload: MuscleWikiExercisePayload,
        exercise: Exercise,
        streamBaseURL: URL = MuscleWikiConfig.streamBaseURL
    ) -> ExerciseFormGuide? {
        let videos = (payload.videos ?? []).compactMap { video -> ExerciseFormGuideVideo? in
            guard let streamURL = resolveStreamURL(from: video, streamBaseURL: streamBaseURL) else { return nil }
            let gender = FormGuideGender(rawValue: (video.gender ?? "male").lowercased()) ?? .male
            let angle = FormGuideAngle(rawValue: (video.angle ?? "front").lowercased()) ?? .front
            let id = "\(gender.rawValue)-\(angle.rawValue)-\(streamURL.lastPathComponent)"
            return ExerciseFormGuideVideo(
                id: id,
                streamURL: streamURL,
                gender: gender,
                angle: angle,
                ogImageURL: video.ogImageURL.flatMap(URL.init(string:))
            )
        }

        let steps = payload.steps ?? []
        guard !videos.isEmpty || !steps.isEmpty else { return nil }

        return ExerciseFormGuide(
            fitLogExerciseId: exercise.id,
            title: payload.name,
            steps: steps,
            videos: videos,
            keyCue: steps.first
        )
    }

    static func resolveStreamURL(from video: MuscleWikiVideoPayload, streamBaseURL: URL) -> URL? {
        let filename = brandedStreamFilename(from: video)
        guard let filename, !filename.isEmpty else { return nil }
        return streamBaseURL.appending(path: filename)
    }

    /// Extracts the branded MP4 filename from MuscleWiki video payload shapes.
    static func brandedStreamFilename(from video: MuscleWikiVideoPayload) -> String? {
        if let urlString = video.url, let url = URL(string: urlString), url.scheme != nil {
            if url.path.contains("/stream/videos/branded/") {
                return url.lastPathComponent.isEmpty ? nil : url.lastPathComponent
            }
            if url.lastPathComponent.hasSuffix(".mp4") {
                return url.lastPathComponent
            }
        }
        let filename = video.filename ?? video.file
        guard let filename, !filename.isEmpty else { return nil }
        return filename
    }
}

struct MuscleWikiExercisePayload: Decodable, Sendable {
    let id: Int
    let name: String
    let steps: [String]?
    let videos: [MuscleWikiVideoPayload]?
}

struct MuscleWikiVideoPayload: Decodable, Sendable {
    let gender: String?
    let angle: String?
    let url: String?
    let filename: String?
    let file: String?
    let ogImageURL: String?

    enum CodingKeys: String, CodingKey {
        case gender, angle, url, filename, file
        case ogImageURL = "og_image_url"
    }
}

struct MuscleWikiSearchEnvelope: Decodable, Sendable {
    let results: [MuscleWikiExercisePayload]
}
