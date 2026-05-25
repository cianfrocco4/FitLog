//
//  HomeGreeting.swift
//  FitLog
//
//  Time-aware personalized greeting copy for the Home hero area.
//

import Foundation

enum HomeGreeting {
    static func timeOfDayPhrase(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    static func firstName(from fullName: String) -> String? {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    static func headline(firstName: String?) -> String {
        let phrase = timeOfDayPhrase()
        if let firstName, !firstName.isEmpty {
            return "\(phrase), \(firstName)"
        }
        return phrase
    }

    static func contextualSubtitle(
        plan: ResolvedScheduleDay,
        weekGlance: DataManager.WeekAtAGlance?,
        scheduledWorkoutName: String?
    ) -> String {
        switch plan {
        case .rest:
            if let glance = weekGlance, glance.completedCount > 0 {
                return "Rest day — you've logged \(glance.completedCount) workout\(glance.completedCount == 1 ? "" : "s") this week."
            }
            return "Rest day — recovery is part of the program."
        case .unscheduled:
            if let glance = weekGlance, glance.completedCount > 0 {
                return "Nothing on the calendar today · \(glance.completedCount) workout\(glance.completedCount == 1 ? "" : "s") this week."
            }
            return "Nothing scheduled — pick a workout below or set your split in Plan."
        case .workout:
            if let name = scheduledWorkoutName, !name.isEmpty {
                return "\(name) is on the schedule today."
            }
            return "You have a workout planned for today."
        }
    }

    static func navigationTitle(firstName: String?) -> String {
        if let firstName, !firstName.isEmpty { return firstName }
        return "FitLog"
    }
}
