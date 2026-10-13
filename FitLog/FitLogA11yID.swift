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

    enum coachDiscussThread {
        static let lastLoad = "fitlog.coachDiscussThread.lastLoad"
    }

    enum blockOperations {
        static let lastLoad = "fitlog.blockOperations.lastLoad"
    }

    enum formGuideVideo {
        static let lastLoad = "fitlog.formGuideVideo.lastLoad"
    }
}
