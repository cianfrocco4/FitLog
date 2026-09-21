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

    enum exercisePill {
        static let lastLoad = "fitlog.exercisePill.lastLoad"
    }

    enum nextExerciseBanner {
        static let lastLoad = "fitlog.nextExerciseBanner.lastLoad"
    }

    enum supersetSwitcher {
        static let lastLoad = "fitlog.supersetSwitcher.lastLoad"
    }
}
