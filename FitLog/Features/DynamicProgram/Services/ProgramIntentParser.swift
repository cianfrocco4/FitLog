//
//  ProgramIntentParser.swift
//  FitLog
//
//  Lightweight keyword extraction from natural-language program requests.
//

import Foundation

enum ProgramIntentParser {
    static func apply(_ text: String, to request: inout DynamicProgramGenerationRequest) {
        let lower = text.lowercased()

        if lower.contains("beginner") {
            request.splitInput.experienceLevel = "Beginner"
        } else if lower.contains("advanced") {
            request.splitInput.experienceLevel = "Advanced"
        } else if lower.contains("intermediate") {
            request.splitInput.experienceLevel = "Intermediate"
        }

        if lower.contains("strength") || lower.contains("stronger") || lower.contains("powerlifting") {
            request.splitInput.primaryGoal = "Get stronger (strength focus)"
        } else if lower.contains("fat loss") || lower.contains("cut") || lower.contains("conditioning") || lower.contains("lose weight") {
            request.splitInput.primaryGoal = "Fat loss / conditioning"
        } else if lower.contains("muscle") || lower.contains("hypertrophy") || lower.contains("size") || lower.contains("bulk") {
            request.splitInput.primaryGoal = "Build muscle & size"
        } else if lower.contains("athletic") || lower.contains("sport") || lower.contains("performance") {
            request.splitInput.primaryGoal = "Athletic / sport performance"
        }

        if lower.contains("push pull") || lower.contains("push/pull") || lower.contains(" ppl") || lower.hasSuffix("ppl") {
            request.splitInput.splitPreference = "Push / Pull / Legs"
        } else if lower.contains("upper lower") || lower.contains("upper/lower") {
            request.splitInput.splitPreference = "Upper / Lower"
        } else if lower.contains("full body") || lower.contains("full-body") {
            request.splitInput.splitPreference = "Full body"
        } else if lower.contains("bro split") || lower.contains("bro ") {
            request.splitInput.splitPreference = "Muscle group (bro) split"
        }

        if lower.contains("dumbbell") && lower.contains("only") {
            request.splitInput.equipment = "Home — dumbbells only"
        } else if lower.contains("bodyweight") || lower.contains("body weight") {
            request.splitInput.equipment = "Mostly bodyweight"
        } else if lower.contains("home") {
            request.splitInput.equipment = "Home — barbell, dumbbells, bench"
        }

        if let sessions = extractSessionsPerWeek(from: lower) {
            request.splitInput.sessionsPerWeek = sessions
        }

        if let weeks = extractTotalWeeks(from: lower) {
            request.isPeriodized = weeks >= 12
        }

        if lower.contains("deload") {
            request.splitInput.deloadPreference = "Lighter week about every 4th week"
        }

        if lower.contains("cardio") {
            request.splitInput.cardioPreference = CardioProgramPreference.mixed.rawValue
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let existing = request.splitInput.additionalNotes
            request.splitInput.additionalNotes = existing.isEmpty ? trimmed : "\(existing)\n\(trimmed)"
        }
    }

    static func extractSessionsPerWeek(from lower: String) -> Int? {
        let patterns = [
            #"(\d)\s*(?:day|days|x)\s*(?:per\s*week|/week|a week)?"#,
            #"(\d)\s*times?\s*(?:per\s*week|a week|weekly)"#,
            #"(\d)\s*sessions?\s*(?:per\s*week|weekly)?"#,
        ]
        for pattern in patterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                let snippet = String(lower[match])
                if let digit = snippet.first(where: \.isNumber), let value = Int(String(digit)) {
                    return min(max(1, value), 7)
                }
            }
        }
        return nil
    }

    static func extractTotalWeeks(from lower: String) -> Int? {
        if let match = lower.range(of: #"(\d+)\s*week"#, options: .regularExpression) {
            let snippet = String(lower[match])
            let digits = snippet.filter(\.isNumber)
            if let value = Int(digits) { return min(max(1, value), 52) }
        }
        return nil
    }
}
