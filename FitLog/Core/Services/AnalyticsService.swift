//
//  AnalyticsService.swift
//  FitLog
//
//  Lightweight product analytics — easy to swap for a backend later.
//

import Foundation
import os

enum AnalyticsEvent: String, Sendable {
    case paywallShown = "paywall_shown"
    case paywallDismissed = "paywall_dismissed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseCancelled = "purchase_cancelled"
    case purchaseFailed = "purchase_failed"
    case aiBlockedByPaywall = "ai_blocked_by_paywall"
    case readinessViewed = "readiness_viewed"
    case readinessAuthorized = "readiness_authorized"
    case firstWorkoutLogged = "first_workout_logged"
    case premiumCompAccessRefreshed = "premium_comp_access_refreshed"
    case restoreCompleted = "restore_completed"
    case restoreFailed = "restore_failed"
    case manageSubscriptionOpened = "manage_subscription_opened"
    case onDeviceAIUsed = "on_device_ai_used"
    case onDeviceAIUnavailable = "on_device_ai_unavailable"
    case aiRoutedCloudFallback = "ai_routed_cloud_fallback"
}

/// Protocol seam for injecting a real analytics backend (RevenueCat events, Mixpanel, etc.).
@MainActor
protocol AnalyticsSink: AnyObject {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

@MainActor
final class LoggerAnalyticsSink: AnalyticsSink {
    private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
        category: "Analytics"
    )

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        if properties.isEmpty {
            log.info("event=\(event.rawValue, privacy: .public)")
        } else {
            let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            log.info("event=\(event.rawValue, privacy: .public) \(props, privacy: .public)")
        }
    }
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    var sink: any AnalyticsSink

    private init() {
        sink = LoggerAnalyticsSink()
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        sink.track(event, properties: properties)
    }
}
