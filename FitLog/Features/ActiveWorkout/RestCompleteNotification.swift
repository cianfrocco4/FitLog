//
//  RestCompleteNotification.swift
//  FitLog
//
//  Local “rest over” notification identity and tap handling (opens logging).
//

import Foundation
import UserNotifications

enum RestCompleteNotification {
    /// Fixed id so skip / finish can cancel the pending rest-over notification.
    static let identifier = "com.fitlog.restTimer.complete"
    static let userInfoOpenLoggingKey = "fitlog.openWorkoutLogging"

    private static let pendingOpenLoggingLock = NSLock()
    private static var pendingOpenLoggingFlag = false

    static var pendingOpenLogging: Bool {
        pendingOpenLoggingLock.lock()
        defer { pendingOpenLoggingLock.unlock() }
        return pendingOpenLoggingFlag
    }

    static func isRestComplete(_ notification: UNNotification) -> Bool {
        notification.request.identifier == identifier
    }

    static func noteOpenLoggingIfNeeded(identifier: String) {
        guard identifier == Self.identifier else { return }
        pendingOpenLoggingLock.lock()
        pendingOpenLoggingFlag = true
        pendingOpenLoggingLock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .fitlogOpenWorkoutLogging, object: nil)
        }
    }

    static func handleTap(_ response: UNNotificationResponse) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        noteOpenLoggingIfNeeded(identifier: response.notification.request.identifier)
    }

    /// True when a rest-complete tap arrived before MainTabView was ready.
    @discardableResult
    static func consumePendingOpenLogging() -> Bool {
        pendingOpenLoggingLock.lock()
        let pending = pendingOpenLoggingFlag
        pendingOpenLoggingFlag = false
        pendingOpenLoggingLock.unlock()
        return pending
    }

    static func resetPendingOpenLoggingForTests() {
        pendingOpenLoggingLock.lock()
        pendingOpenLoggingFlag = false
        pendingOpenLoggingLock.unlock()
    }
}

/// Retained `UNUserNotificationCenter` delegate so rest-complete taps open logging.
final class FitLogUserNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FitLogUserNotificationDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if RestCompleteNotification.isRestComplete(notification) {
            // In-app rest-complete chrome already handles this while the app is foregrounded.
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        RestCompleteNotification.handleTap(response)
        completionHandler()
    }
}
