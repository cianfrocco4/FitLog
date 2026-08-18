//
//  FormGuideVideoAssetTests.swift
//  FitLogTests
//

import AVFoundation
import Foundation
import Testing
@testable import FitLog

struct FormGuideVideoAssetTests {

    @Test func makeURLAsset_withoutHeaders_usesPlainURL() {
        let url = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded/squat.mp4")!
        let asset = FormGuideVideoAsset.makeURLAsset(url: url, headers: [:])
        #expect(asset.url == url)
    }

    @Test func makeURLAsset_withHeaders_preservesStreamURL() {
        let url = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded/bench-press.mp4")!
        let headers = [FitLogProxyConfig.proxySecretHeaderName: "secret"]
        let asset = FormGuideVideoAsset.makeURLAsset(url: url, headers: headers)
        #expect(asset.url == url)
    }

    @Test func shouldApplyPlaybackEvent_rejectsStaleVideoOrRetry() {
        #expect(
            FormGuideVideoAsset.shouldApplyPlaybackEvent(
                configuredVideoID: "squat",
                configuredRetryGeneration: 1,
                eventVideoID: "squat",
                eventRetryGeneration: 1
            )
        )
        #expect(
            !FormGuideVideoAsset.shouldApplyPlaybackEvent(
                configuredVideoID: "squat",
                configuredRetryGeneration: 2,
                eventVideoID: "squat",
                eventRetryGeneration: 1
            )
        )
        #expect(
            !FormGuideVideoAsset.shouldApplyPlaybackEvent(
                configuredVideoID: "bench",
                configuredRetryGeneration: 1,
                eventVideoID: "squat",
                eventRetryGeneration: 1
            )
        )
        #expect(
            !FormGuideVideoAsset.shouldApplyPlaybackEvent(
                configuredVideoID: nil,
                configuredRetryGeneration: nil,
                eventVideoID: "squat",
                eventRetryGeneration: 0
            )
        )
    }
}
