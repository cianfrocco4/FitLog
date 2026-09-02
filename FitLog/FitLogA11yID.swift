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
    /// Last-session recap on a saved workout, Personal Records, or exercise detail.
    static let libraryWorkoutLastSession = "fitlog.libraryWorkout.lastSession"
    static let personalRecordStartWorkout = "fitlog.personalRecord.startWorkout"
    static let exerciseDetailStartWorkout = "fitlog.exerciseDetail.startWorkout"
}
