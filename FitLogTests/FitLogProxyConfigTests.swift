//
//  FitLogProxyConfigTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct FitLogProxyConfigTests {

    @Test func videoStreamHeaders_proxyMode_usesSharedSecret() {
        let headers = FitLogProxyConfig.videoStreamHeaders(
            usesProxy: true,
            proxySharedSecret: "abc123",
            muscleWikiAPIKey: "mw_should_not_leak"
        )
        #expect(headers == [FitLogProxyConfig.proxySecretHeaderName: "abc123"])
    }

    @Test func videoStreamHeaders_proxyMode_emptyWithoutSecret() {
        let headers = FitLogProxyConfig.videoStreamHeaders(
            usesProxy: true,
            proxySharedSecret: "  ",
            muscleWikiAPIKey: "mw_key"
        )
        #expect(headers.isEmpty)
    }

    @Test func videoStreamHeaders_directMode_usesMuscleWikiKey() {
        let headers = FitLogProxyConfig.videoStreamHeaders(
            usesProxy: false,
            proxySharedSecret: "abc123",
            muscleWikiAPIKey: "mw_live"
        )
        #expect(headers == [FitLogProxyConfig.muscleWikiAPIKeyHeaderName: "mw_live"])
    }

    @Test func videoStreamHeaders_directMode_emptyWithoutKey() {
        let headers = FitLogProxyConfig.videoStreamHeaders(
            usesProxy: false,
            proxySharedSecret: "abc123",
            muscleWikiAPIKey: nil
        )
        #expect(headers.isEmpty)
    }
}
