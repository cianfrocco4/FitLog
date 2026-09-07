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
    /// Last completed session recap at the top of Daily Adjust (Home sheet).
    static let dailyAdjustLastSession = "fitlog.dailyAdjust.lastSession"
    static let dailyAdjustStartThisWorkout = "fitlog.dailyAdjust.startThisWorkout"
    /// Last session recap on More → Body measurements.
    static let bodyMeasurementsLastSession = "fitlog.bodyMeasurements.lastSession"
    static let bodyMeasurementsStartThisWorkout = "fitlog.bodyMeasurements.startThisWorkout"
    /// Last session recap on More → Progress photos.
    static let progressPhotosLastSession = "fitlog.progressPhotos.lastSession"
    static let progressPhotosStartThisWorkout = "fitlog.progressPhotos.startThisWorkout"
}
