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
}
