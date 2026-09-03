//
//  FitLogA11yID.swift
//  FitLog
//
//  Stable accessibility identifiers for XCUITest and Simulator exploration bots.
//  Keep in sync with docs/AUTOMATED_USER_TESTING.md and FitLogUITests.
//

enum FitLogA11yID {
    static let startWorkout = "fitlog.startWorkout"
    static let newWorkout = "fitlog.newWorkout"
    static let fromTemplate = "fitlog.fromTemplate"
    static let createWorkout = "fitlog.createWorkout"
    static let quickStartPushA = "fitlog.quickStart.pushA"
    /// Last completed session recap at the top of the History tab (all subtabs).
    static let historyTabLastSession = "fitlog.historyTab.lastSession"
    static let historyTabStartThisWorkout = "fitlog.historyTab.startThisWorkout"
    /// Last session recap inside Home week-in-review (free + Premium).
    static let weeklyInsightLastSession = "fitlog.weeklyInsight.lastSession"
    static let weeklyInsightStartWorkout = "fitlog.weeklyInsight.startWorkout"
}
