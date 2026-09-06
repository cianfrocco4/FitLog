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
    /// Last completed session recap under the Home week strip.
    static let homeWeekStripLastSession = "fitlog.homeWeekStrip.lastSession"
    static let homeWeekStripStartThisWorkout = "fitlog.homeWeekStrip.startThisWorkout"
    /// Last session recap on the program template gallery (not program-builder entry).
    static let programGalleryLastSession = "fitlog.programGallery.lastSession"
    static let programGalleryStartThisWorkout = "fitlog.programGallery.startThisWorkout"
    /// Last session recap at the top of More → Subscription.
    static let subscriptionSettingsLastSession = "fitlog.subscriptionSettings.lastSession"
    static let subscriptionSettingsStartThisWorkout = "fitlog.subscriptionSettings.startThisWorkout"
}
