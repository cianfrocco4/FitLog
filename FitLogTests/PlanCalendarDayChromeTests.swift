//
//  PlanCalendarDayChromeTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

@Suite
struct PlanCalendarDayChromeTests {
    @Test func todayDoneCaption_onlyWhenLoggedToday() {
        #expect(PlanCalendarDayChrome.todayDoneCaption(isToday: true, isLogged: true) == "Done")
        #expect(PlanCalendarDayChrome.todayDoneCaption(isToday: true, isLogged: false) == nil)
        #expect(PlanCalendarDayChrome.todayDoneCaption(isToday: false, isLogged: true) == nil)
    }

    @Test func emphasizesCompletedToday() {
        #expect(PlanCalendarDayChrome.emphasizesCompletedToday(isToday: true, isLogged: true))
        #expect(!PlanCalendarDayChrome.emphasizesCompletedToday(isToday: true, isLogged: false))
        #expect(!PlanCalendarDayChrome.emphasizesCompletedToday(isToday: false, isLogged: true))
    }

    @Test func accessibilityStatus_callsOutCheckedOffToday() {
        #expect(
            PlanCalendarDayChrome.accessibilityStatus(
                isToday: true,
                isLogged: true,
                baseStatus: "Logged workout"
            ) == "Logged workout. Today is checked off."
        )
        #expect(
            PlanCalendarDayChrome.accessibilityStatus(
                isToday: false,
                isLogged: true,
                baseStatus: "Logged workout"
            ) == "Logged workout"
        )
    }
}
