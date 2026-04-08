//
//  FitLogUITestLaunch.swift
//  FitLog
//
//  When UI tests pass `-fitlog-ui-testing` / `FITLOG_UI_TESTING=1`, the app skips flows
//  that commonly stall or flake on Xcode Cloud (Sign in with Apple credential refresh,
//  notification permission prompts, etc.). Does not affect normal installs.
//

import Foundation

enum FitLogUITestLaunch {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-testing")
            || ProcessInfo.processInfo.environment["FITLOG_UI_TESTING"] == "1"
    }
}
