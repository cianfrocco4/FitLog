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

    static let newExerciseSheetLastSession = "fitlog.newExerciseSheet.lastSession"
    static let newExerciseSheetStartThisWorkout = "fitlog.newExerciseSheet.startThisWorkout"
    static let coachChatHistoryLastSession = "fitlog.coachChatHistory.lastSession"
    static let coachChatHistoryStartThisWorkout = "fitlog.coachChatHistory.startThisWorkout"
    static let applySplitLastSession = "fitlog.applySplit.lastSession"
    static let applySplitStartThisWorkout = "fitlog.applySplit.startThisWorkout"
}
