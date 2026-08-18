//
//  FitLogSimulatedUserReview.swift
//  FitLog
//
//  One living user's report: likes, dislikes, bugs, and workflow notes.
//

import Foundation

struct FitLogSimulatedUserReviewNote: Codable, Equatable, Sendable {
    var id: String
    var area: String
    var detail: String
}

struct FitLogSimulatedUserReview: Codable, Equatable, Sendable {
    var persona: String
    var displayName: String
    var dayKey: String
    var generatedAt: String
    var isPremium: Bool
    var isTrainingDay: Bool
    var tickOutcome: String?
    var sessionCount: Int
    var libraryCount: Int
    var lastWorkoutName: String?
    var oldestSessionDaysAgo: Int?
    var likes: [FitLogSimulatedUserReviewNote]
    var dislikes: [FitLogSimulatedUserReviewNote]
    var bugs: [FitLogSimulatedUserReviewNote]
    var improvements: [FitLogSimulatedUserReviewNote]
    var workflow: String

    func markdown() -> String {
        var lines: [String] = []
        lines.append("## \(displayName) (`\(persona)`) — \(dayKey)")
        lines.append("")
        let premium = isPremium ? "Premium" : "Free"
        let training = isTrainingDay ? "training day" : "rest day"
        let tick = tickOutcome ?? "none"
        lines.append(
            "\(premium) · \(training) · tick: `\(tick)` · sessions: \(sessionCount) · library: \(libraryCount)"
        )
        if let lastWorkoutName {
            lines.append("Last workout: \(lastWorkoutName)")
        }
        if let oldestSessionDaysAgo {
            lines.append("Oldest session: \(oldestSessionDaysAgo) day(s) ago")
        }
        lines.append("")
        lines.append(section("Likes", likes))
        lines.append(section("Dislikes", dislikes))
        lines.append(section("Bugs", bugs))
        lines.append(section("Improvements", improvements))
        lines.append("### Workflow")
        lines.append("")
        lines.append(workflow)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func section(_ title: String, _ notes: [FitLogSimulatedUserReviewNote]) -> String {
        var lines = ["### \(title)", ""]
        if notes.isEmpty {
            lines.append("_None reported._")
        } else {
            for note in notes {
                lines.append("- **\(note.area)** (`\(note.id)`): \(note.detail)")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
