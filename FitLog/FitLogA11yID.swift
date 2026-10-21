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

    enum coachChat {
        static let lastLoad = "fitlog.coachChat.lastLoad"
    }

    enum cardioRowEditor {
        static let lastLoad = "fitlog.cardioRowEditor.lastLoad"
    }

    enum moreTab {
        static let lastLoad = "fitlog.moreTab.lastLoad"
    }
}
