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

    enum exerciseHistory {
        static let lastLoad = "fitlog.exerciseHistory.lastLoad"
    }

    enum personalRecords {
        static let lastLoad = "fitlog.personalRecords.lastLoad"
    }

    enum homeStartSheet {
        static let lastLoad = "fitlog.homeStartSheet.lastLoad"
    }
}
