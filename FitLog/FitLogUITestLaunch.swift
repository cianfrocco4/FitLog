//
//  FitLogUITestLaunch.swift
//  FitLog
//
//  When automated tests run (`-fitlog-ui-testing`, `FITLOG_UI_TESTING=1`, hosted unit tests,
//  or CI), the app skips flows that commonly stall or flake on Xcode Cloud (Sign in with Apple
//  credential refresh, notification permission prompts, etc.). Does not affect normal installs.
//
//  Premium unlock / fake login for UI tests are DEBUG-only (see EntitlementStore, AuthViewModel).
//

import Foundation

enum FitLogUITestLaunch {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-testing")
            || ProcessInfo.processInfo.environment["FITLOG_UI_TESTING"] == "1"
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["CI"] == "true"
            || ProcessInfo.processInfo.environment["XCODE_CLOUD"] == "1"
    }

    /// UI tests that exercise onboarding omit `-fitlog-skip-onboarding`.
    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-skip-onboarding")
            || ProcessInfo.processInfo.environment["FITLOG_SKIP_ONBOARDING"] == "1"
    }

    /// Clears first-run flags so onboarding is shown even if a previous UI test completed it.
    static var shouldForceOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-force-onboarding")
    }
}
