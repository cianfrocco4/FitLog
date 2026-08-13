//
//  WidgetSnapshotStoreTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WidgetSnapshotStoreTests {

    @Test func payload_encodeDecode_roundTrip() throws {
        let payload = WidgetSnapshotStore.Payload(
            readinessScore: 72,
            readinessSummary: "Good readiness",
            readinessBandTitle: "Good readiness",
            todayPlanTitle: "Upper body",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WidgetSnapshotStore.Payload.self, from: data)

        #expect(decoded.readinessScore == payload.readinessScore)
        #expect(decoded.readinessSummary == payload.readinessSummary)
        #expect(decoded.readinessBandTitle == payload.readinessBandTitle)
        #expect(decoded.todayPlanTitle == payload.todayPlanTitle)
        #expect(decoded.updatedAt == payload.updatedAt)
    }

    @Test func resolveConnectState_mapsExpectedCases() {
        #expect(ReadinessViewModel.resolveConnectState(
            isHealthDataAvailable: false,
            hasMetrics: false,
            authorizationAttempted: false
        ) == .hidden)
        #expect(ReadinessViewModel.resolveConnectState(
            isHealthDataAvailable: true,
            hasMetrics: true,
            authorizationAttempted: false
        ) == .hidden)
        #expect(ReadinessViewModel.resolveConnectState(
            isHealthDataAvailable: true,
            hasMetrics: false,
            authorizationAttempted: false
        ) == .connect)
        #expect(ReadinessViewModel.resolveConnectState(
            isHealthDataAvailable: true,
            hasMetrics: false,
            authorizationAttempted: true
        ) == .noData)
    }

    @Test func freshness_isStaleAfterTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let fresh = now.addingTimeInterval(-3_600)
        let stale = now.addingTimeInterval(-(24 * 60 * 60))
        #expect(!WidgetSnapshotFreshness.isStale(updatedAt: fresh, now: now))
        #expect(WidgetSnapshotFreshness.isStale(updatedAt: stale, now: now))
    }

    @Test func freshness_updatedCaption_marksStaleSnapshots() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let updatedAt = now.addingTimeInterval(-(30 * 60 * 60))
        let caption = WidgetSnapshotFreshness.updatedCaption(
            updatedAt: updatedAt,
            now: now,
            relativePhrase: "30 hours ago"
        )
        #expect(caption == "Updated 30 hours ago · May be outdated")

        let a11y = WidgetSnapshotFreshness.accessibilityUpdatedSuffix(
            updatedAt: updatedAt,
            now: now,
            relativePhrase: "30 hours ago"
        )
        #expect(a11y == "Updated 30 hours ago, may be outdated")
    }

    @Test func freshness_updatedCaption_freshSnapshot() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let updatedAt = now.addingTimeInterval(-900)
        let caption = WidgetSnapshotFreshness.updatedCaption(
            updatedAt: updatedAt,
            now: now,
            relativePhrase: "15 minutes ago"
        )
        #expect(caption == "Updated 15 minutes ago")
    }
}
