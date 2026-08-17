//
//  FitLogUITestLaunch.swift
//  FitLog
//
//  When automated tests run (`-fitlog-ui-testing`, `FITLOG_UI_TESTING=1`, hosted unit tests,
//  or CI), the app skips flows that commonly stall or flake on Xcode Cloud (Sign in with Apple
//  credential refresh, notification permission prompts, etc.). Does not affect normal installs.
//
//  Premium unlock / fake login for UI tests are DEBUG-only (see EntitlementStore, AuthViewModel).
//  Optional `-fitlog-ui-persona` seeds a simulated user after `-fitlog-ui-reset-store`.
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

    /// Wipe local workouts/history on launch so each XCUITest starts from a known store.
    static var shouldResetStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-reset-store")
            || ProcessInfo.processInfo.environment["FITLOG_UI_RESET_STORE"] == "1"
    }

    static var persona: FitLogSimulatedUserPersona? {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-fitlog-ui-persona"), idx + 1 < args.count {
            return FitLogSimulatedUserPersona(rawValue: args[idx + 1])
        }
        if let env = ProcessInfo.processInfo.environment["FITLOG_UI_PERSONA"], !env.isEmpty {
            return FitLogSimulatedUserPersona(rawValue: env)
        }
        return nil
    }
}
