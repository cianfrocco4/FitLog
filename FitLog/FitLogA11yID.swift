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

    enum collapsedBar {
        static let lastLoad = "fitlog.collapsedBar.lastLoad"
    }

    enum restTimer {
        static let lastLoad = "fitlog.restTimer.lastLoad"
    }

    enum homeActiveWorkout {
        static let lastLoad = "fitlog.homeActiveWorkout.lastLoad"
    }
}
