//
//  PlanCalendarDayChrome.swift
//  FitLog
//
//  Stronger “logged today” treatment so the Plan week looks done after a session.
//

import Foundation

enum PlanCalendarDayChrome {
    /// Caption under today when that planned (or ad hoc) session is already logged.
    static func todayDoneCaption(isToday: Bool, isLogged: Bool) -> String? {
        guard isToday, isLogged else { return nil }
        return "Done"
    }

    static func emphasizesCompletedToday(isToday: Bool, isLogged: Bool) -> Bool {
        isToday && isLogged
    }

    /// VoiceOver suffix so a logged today cell is not just a tiny checkmark.
    static func accessibilityStatus(isToday: Bool, isLogged: Bool, baseStatus: String) -> String {
        if emphasizesCompletedToday(isToday: isToday, isLogged: isLogged) {
            return "\(baseStatus). Today is checked off."
        }
        return baseStatus
    }
}
