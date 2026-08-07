//
//  RestTimerLiveActivityCoordinator.swift
//  FitLog
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Drives the Lock Screen / Dynamic Island rest countdown via ActivityKit.
@MainActor
final class RestTimerLiveActivityCoordinator {
    static let shared = RestTimerLiveActivityCoordinator()

    private init() {}

    #if canImport(ActivityKit)
    private var activity: Activity<RestTimerActivityAttributes>?
    #endif

    func syncRestCountdown(remainingSeconds: Int, workoutName: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard remainingSeconds > 0 else {
            endRestActivity()
            return
        }
        let state = RestTimerActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            headline: "Rest between sets"
        )
        if let existing = activity {
            Task { @MainActor in
                await existing.update(ActivityContent(state: state, staleDate: nil))
            }
            return
        }
        let attrs = RestTimerActivityAttributes(workoutName: workoutName)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            // Activity.request is synchronous (throws) on current SDKs.
            activity = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
        #endif
    }

    func endRestActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let act = activity else { return }
        activity = nil
        Task { @MainActor in
            await act.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }
}
