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
    /// Last completed session recap at the top of More (not History / week-in-review).
    static let moreTabLastSession = "fitlog.moreTab.lastSession"
    static let moreTabStartThisWorkout = "fitlog.moreTab.startThisWorkout"
    /// Last session recap on the active-program hub (not Home program card / Plan day).
    static let programDetailLastSession = "fitlog.programDetail.lastSession"
    static let programDetailStartThisWorkout = "fitlog.programDetail.startThisWorkout"
    /// Last duration recap inside the cardio workout builder (not Home cardio duration).
    static let cardioBuilderLastSession = "fitlog.cardioBuilder.lastSession"
    static let cardioBuilderStartWorkout = "fitlog.cardioBuilder.startWorkout"
}
