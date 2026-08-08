//
//  PurchaseRestoreMessagingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct PurchaseRestoreMessagingTests {

    @Test func networkURLError_mapsToConnectionCopy() {
        let error = URLError(.notConnectedToInternet)
        #expect(PurchaseRestoreMessaging.isLikelyNetworkFailure(error))
        #expect(
            PurchaseRestoreMessaging.userFacingFailureMessage(for: error)
                == PurchaseRestoreMessaging.networkFailure
        )
    }

    @Test func timedOut_mapsToConnectionCopy() {
        let error = URLError(.timedOut)
        #expect(
            PurchaseRestoreMessaging.userFacingFailureMessage(for: error)
                == PurchaseRestoreMessaging.networkFailure
        )
    }

    @Test func wrappedUnderlyingNetworkError_isDetected() {
        let underlying = URLError(.networkConnectionLost)
        let wrapped = NSError(
            domain: "RevenueCat.ErrorCode",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        #expect(PurchaseRestoreMessaging.isLikelyNetworkFailure(wrapped))
        #expect(
            PurchaseRestoreMessaging.userFacingFailureMessage(for: wrapped)
                == PurchaseRestoreMessaging.networkFailure
        )
    }

    @Test func purchaseServiceNotConfigured_keepsLocalizedCopy() {
        let message = PurchaseRestoreMessaging.userFacingFailureMessage(
            for: PurchaseServiceError.notConfigured
        )
        #expect(message == PurchaseServiceError.notConfigured.errorDescription)
    }

    @Test func longOpaqueError_fallsBackToGeneric() {
        let long = String(repeating: "x", count: 200)
        let error = NSError(domain: "Test", code: 99, userInfo: [NSLocalizedDescriptionKey: long])
        #expect(
            PurchaseRestoreMessaging.userFacingFailureMessage(for: error)
                == PurchaseRestoreMessaging.genericFailure
        )
    }
}
