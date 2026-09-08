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
    /// Last completed session recap on More → Data & Integrations.
    static let dataIntegrationsLastSession = "fitlog.dataIntegrations.lastSession"
    static let dataIntegrationsStartThisWorkout = "fitlog.dataIntegrations.startThisWorkout"
    /// Last session recap above the History Overview training heatmap.
    static let historyHeatmapLastSession = "fitlog.historyHeatmap.lastSession"
    static let historyHeatmapStartThisWorkout = "fitlog.historyHeatmap.startThisWorkout"
    /// Last session recap on the Home Premium teaser (Start stays ungated; See Premium is unchanged).
    static let homePremiumCardLastSession = "fitlog.homePremiumCard.lastSession"
    static let homePremiumCardStartThisWorkout = "fitlog.homePremiumCard.startThisWorkout"
}
