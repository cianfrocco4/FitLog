//
//  FitLogUITestSupport.swift
//  FitLogUITests
//
//  Shared launch configuration for Xcode Cloud / simulator UI tests.
//

import XCTest

enum FitLogUITestSupport {

    /// Call before `launch()`. Skips Apple credential checks and notification prompts in the app.
    /// - Parameter skipOnboarding: Pass `false` to exercise the first-run onboarding UI.
    /// - Parameter forceOnboarding: Reset first-run flags so onboarding appears even after other tests.
    static func configure(
        _ app: XCUIApplication,
        skipOnboarding: Bool = true,
        forceOnboarding: Bool = false
    ) {
        app.launchArguments.append("-fitlog-ui-testing")
        app.launchEnvironment["FITLOG_UI_TESTING"] = "1"
        if skipOnboarding {
            app.launchArguments.append("-fitlog-skip-onboarding")
            app.launchEnvironment["FITLOG_SKIP_ONBOARDING"] = "1"
        }
        if forceOnboarding {
            app.launchArguments.append("-fitlog-force-onboarding")
        }
    }
}
