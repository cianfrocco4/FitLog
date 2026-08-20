//
//  HomeGreeting.swift
//  FitLog
//
//  Personalized Home copy: first name, navigation title, and today subtitle.
//

import Foundation

enum HomeGreeting {
    static func firstName(from fullName: String) -> String? {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    static func contextualSubtitle(
        plan: ResolvedScheduleDay,
        weekGlance: DataManager.WeekAtAGlance?,
        scheduledWorkoutName: String?,
        hasCompletedSessionToday: Bool = false
    ) -> String {
        if hasCompletedSessionToday {
            return alreadyTrainedSubtitle(plan: plan, scheduledWorkoutName: scheduledWorkoutName)
        }

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

    /// Leads with completion so Home doesn't look like the user still needs to start (`improve.home.already_trained`).
    private static func alreadyTrainedSubtitle(
        plan: ResolvedScheduleDay,
        scheduledWorkoutName: String?
    ) -> String {
        switch plan {
        case .rest:
            return "You already trained today — enjoy the rest of your recovery day."
        case .unscheduled:
            return "You already trained today — nice work. Start another only if you want extra volume."
        case .workout:
            if let name = scheduledWorkoutName, !name.isEmpty {
                return "You already trained today — \(name) is done. Continue or start fresh below if you need more."
            }
            return "You already trained today — your planned workout is done. Continue or start fresh below if you need more."
        }
    }

    static func navigationTitle(firstName: String?) -> String {
        if let firstName, !firstName.isEmpty { return firstName }
        return AppBrand.name
    }
}
