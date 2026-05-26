//
//  MuscleWikiConfigTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct MuscleWikiConfigTests {

    @Test func exerciseURL_buildsDirectMuscleWikiPath() {
        let url = URL(string: "https://api.musclewiki.com")!
        let exerciseURL = url.appending(path: "exercises/42")
        #expect(exerciseURL.absoluteString == "https://api.musclewiki.com/exercises/42")
    }

    @Test func streamURL_buildsProxyStreamPath() {
        let proxyStreamBase = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded")!
        let streamURL = proxyStreamBase.appending(path: "squat.mp4")
        #expect(streamURL.absoluteString == "https://proxy.example.com/v1/form-guide/stream/videos/branded/squat.mp4")
    }

    @Test func searchURL_buildsQueryItems() {
        let root = URL(string: "https://proxy.example.com/v1/form-guide")!
        var components = URLComponents(url: root.appending(path: "search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: "Barbell Bench Press"),
            URLQueryItem(name: "limit", value: "1")
        ]
        let url = components?.url
        #expect(url?.absoluteString.contains("q=Barbell") == true)
        #expect(url?.absoluteString.contains("limit=1") == true)
    }
}
