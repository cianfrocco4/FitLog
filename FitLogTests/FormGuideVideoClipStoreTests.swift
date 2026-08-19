//
//  FormGuideVideoClipStoreTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct FormGuideVideoClipStoreTests {

    @Test func validatePlayableDownload_rejectsUnauthorizedJSON() throws {
        let url = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded/squat.mp4")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let file = try writeTempFile(Data("{}".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            try FormGuideVideoResponseValidator.validatePlayableDownload(response: response, fileURL: file)
            Issue.record("Expected unauthorized JSON to be rejected")
        } catch let error as FormGuideVideoClipError {
            #expect(error == .notAuthorized)
        }
    }

    @Test func validatePlayableDownload_rejectsJSONEvenWith200() throws {
        let url = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded/squat.mp4")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let file = try writeTempFile(Data("{\"error\":\"Unauthorized\"}".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            try FormGuideVideoResponseValidator.validatePlayableDownload(response: response, fileURL: file)
            Issue.record("Expected JSON body to be rejected as not video")
        } catch let error as FormGuideVideoClipError {
            #expect(error == .notVideo)
        }
    }

    @Test func validatePlayableDownload_acceptsISOMediaWithFtypBox() throws {
        let url = URL(string: "https://proxy.example.com/v1/form-guide/stream/videos/branded/squat.mp4")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "video/mp4"]
        )!
        var payload = Data([0x00, 0x00, 0x00, 0x20])
        payload.append(contentsOf: Array("ftypisom".utf8))
        let file = try writeTempFile(payload)
        defer { try? FileManager.default.removeItem(at: file) }

        try FormGuideVideoResponseValidator.validatePlayableDownload(response: response, fileURL: file)
        #expect(FormGuideVideoResponseValidator.hasISOMediaFtyp(at: file))
    }

    @Test func localFile_fileURL_returnsSameURLWithoutNetwork() async throws {
        let store = FormGuideVideoClipStore()
        let fileURL = URL(fileURLWithPath: "/tmp/form-guide-preview.mp4")
        let result = try await store.localFile(for: fileURL, headers: ["X-FitLog-Proxy-Secret": "unused"])
        #expect(result == fileURL)
    }

    private func writeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "form-guide-test-\(UUID().uuidString).bin")
        try data.write(to: url)
        return url
    }
}
