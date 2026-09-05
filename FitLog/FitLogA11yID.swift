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
    /// Last completed session recap at the top of Coach (above the Premium banner).
    static let coachTabLastSession = "fitlog.coachTab.lastSession"
    static let coachTabStartThisWorkout = "fitlog.coachTab.startThisWorkout"
    /// Last session recap on program-builder entry (not the active-program hub).
    static let programBuilderLastSession = "fitlog.programBuilder.lastSession"
    static let programBuilderStartThisWorkout = "fitlog.programBuilder.startThisWorkout"
    /// Last session recap on the empty Plan hero (no program assigned yet).
    static let planEmptyLastSession = "fitlog.planEmpty.lastSession"
    static let planEmptyStartThisWorkout = "fitlog.planEmpty.startThisWorkout"
}
