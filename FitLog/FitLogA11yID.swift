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

    enum coachChatBubble {
        static let lastLoad = "fitlog.coachChatBubble.lastLoad"
    }

    enum firstRunHero {
        static let lastLoad = "fitlog.firstRunHero.lastLoad"
    }

    enum coachTrainerBubble {
        static let lastLoad = "fitlog.coachTrainerBubble.lastLoad"
    }
}
