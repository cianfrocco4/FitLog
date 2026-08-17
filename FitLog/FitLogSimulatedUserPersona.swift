//
//  FitLogSimulatedUserPersona.swift
//  FitLog
//
//  Catalog of distinct simulated users for XCUITest and Mac exploratory bots.
//

import Foundation

/// One realistic gym-goer. Pass `-fitlog-ui-persona <rawValue>` (or `FITLOG_UI_PERSONA`) at launch.
enum FitLogSimulatedUserPersona: String, CaseIterable, Sendable {
    case newFree
    case returningFree
    case premiumLifter
    case cardioHobbyist
    case planFollower

    var isPremium: Bool {
        self == .premiumLifter
    }

    var displayName: String {
        switch self {
        case .newFree: return "New free user"
        case .returningFree: return "Returning free lifter"
        case .premiumLifter: return "Premium lifter"
        case .cardioHobbyist: return "Cardio hobbyist"
        case .planFollower: return "Plan follower"
        }
    }

    var workflowSummary: String {
        switch self {
        case .newFree:
            return "Empty Home → create Push A → Coach Premium gate."
        case .returningFree:
            return "Start a recent library workout; History stays on 14 days when 30-day range is locked."
        case .premiumLifter:
            return "Home has training history; Subscription shows Active; Coach is entitled (AI may still be unconfigured)."
        case .cardioHobbyist:
            return "Home lists a Zone 2 cardio workout from the template library."
        case .planFollower:
            return "Today is a planned Push A day on the Plan calendar."
        }
    }

    /// Ordered catalog used when simulating the first N users.
    static var catalog: [FitLogSimulatedUserPersona] { allCases }
}
