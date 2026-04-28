//
//  FitLogUITestSupport.swift
//  FitLogUITests
//
//  Shared launch configuration for Xcode Cloud / simulator UI tests.
//

import XCTest

enum FitLogUITestSupport {

    /// Call before `launch()`. Skips Apple credential checks and notification prompts in the app.
    static func configure(_ app: XCUIApplication) {
        app.launchArguments.append("-fitlog-ui-testing")
        app.launchEnvironment["FITLOG_UI_TESTING"] = "1"
    }
}
