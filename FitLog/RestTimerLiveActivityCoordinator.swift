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
            Task {
                await existing.update(ActivityContent(state: state, staleDate: nil))
            }
            return
        }
        let attrs = RestTimerActivityAttributes(workoutName: workoutName)
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            do {
                activity = try await Activity.request(attributes: attrs, content: content, pushType: nil)
            } catch {
                activity = nil
            }
        }
        #endif
    }

    func endRestActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let act = activity else { return }
        Task {
            await act.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        #endif
    }
}
