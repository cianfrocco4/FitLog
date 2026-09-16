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

    enum slotDetailEditor {
        static let lastLoad = "fitlog.slotDetailEditor.lastLoad"
        static let useLastLoad = "fitlog.slotDetailEditor.useLastLoad"
    }

    enum dayPagerSlot {
        static let lastLoad = "fitlog.dayPagerSlot.lastLoad"
    }

    enum blockTemplateSlot {
        static let lastLoad = "fitlog.blockTemplateSlot.lastLoad"
    }

    enum importRotation {
        static let lastLoad = "fitlog.importRotation.lastLoad"
    }
}
