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
        #expect(decoded.lastSessionTitle == nil)
        #expect(decoded.lastSessionSubtitle == nil)
        #expect(decoded.updatedAt == payload.updatedAt)
    }

    @Test func payload_decodesLegacyJSONWithoutLastSession() throws {
        let payload = WidgetSnapshotStore.Payload(
            readinessScore: 70,
            readinessSummary: "Good",
            readinessBandTitle: "Good",
            todayPlanTitle: "Rest day",
            lastSessionTitle: "Push A",
            lastSessionSubtitle: "Today · 40 min",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoded = try JSONEncoder().encode(payload)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object.removeValue(forKey: "lastSessionTitle")
        object.removeValue(forKey: "lastSessionSubtitle")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(WidgetSnapshotStore.Payload.self, from: stripped)
        #expect(decoded.readinessScore == 70)
        #expect(decoded.todayPlanTitle == "Rest day")
        #expect(decoded.lastSessionTitle == nil)
        #expect(decoded.lastSessionSubtitle == nil)
    }

    @Test func payload_roundTripLastSession() throws {
        let payload = WidgetSnapshotStore.Payload(
            readinessScore: 64,
            readinessSummary: "Moderate",
            readinessBandTitle: "Moderate",
            todayPlanTitle: "Rest day",
            lastSessionTitle: "Zone 2",
            lastSessionSubtitle: "Today · 45 min",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let decoded = try JSONDecoder().decode(
            WidgetSnapshotStore.Payload.self,
            from: try JSONEncoder().encode(payload)
        )
        #expect(decoded.lastSessionTitle == "Zone 2")
        #expect(decoded.lastSessionSubtitle == "Today · 45 min")
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
}
