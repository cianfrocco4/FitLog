//
//  FitLogUITestLaunch.swift
//  FitLog
//
//  When automated tests run (`-fitlog-ui-testing`, `FITLOG_UI_TESTING=1`, hosted unit tests,
//  or CI), the app skips flows that commonly stall or flake on Xcode Cloud (Sign in with Apple
//  credential refresh, notification permission prompts, etc.). Does not affect normal installs.
//
//  Premium unlock / fake login for UI tests are DEBUG-only (see EntitlementStore, AuthViewModel).
//  Optional `-fitlog-ui-persona` seeds a snapshot user after `-fitlog-ui-reset-store`.
//  Daily living: `-fitlog-ui-daily-living -fitlog-ui-persistent-store -fitlog-ui-persona <id>`
//  (does not reset; each persona has its own FitLogData-sim-*.store).
//  Reviews: `-fitlog-ui-write-review` writes likes/dislikes/bugs to Documents JSONL.
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

    /// Keep per-persona SwiftData files so daily living runs accumulate History.
    static var usesPersistentPersonaStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-persistent-store")
            || ProcessInfo.processInfo.environment["FITLOG_UI_PERSISTENT_STORE"] == "1"
            || isDailyLiving
    }

    /// One calendar tick: bootstrap if needed, then log today when it is a training day.
    static var isDailyLiving: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-daily-living")
            || ProcessInfo.processInfo.environment["FITLOG_UI_DAILY_LIVING"] == "1"
    }

    /// After launch (and after a living tick when that flag is set), write a likes/dislikes/bugs report.
    static var shouldWriteReview: Bool {
        ProcessInfo.processInfo.arguments.contains("-fitlog-ui-write-review")
            || ProcessInfo.processInfo.environment["FITLOG_UI_WRITE_REVIEW"] == "1"
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

    /// SwiftData filename. Living users isolate stores so five personas can share one Simulator.
    static var modelStoreFileName: String {
        if usesPersistentPersonaStore, let persona {
            return persona.persistentStoreFileName
        }
        return "FitLogData.store"
    }
}
