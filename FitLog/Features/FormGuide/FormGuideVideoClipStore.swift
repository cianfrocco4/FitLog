//
//  FormGuideVideoClipStore.swift
//  FitLog
//
//  Downloads authenticated form-guide MP4s with URLSession, then plays from disk.
//  AVPlayer does not reliably send custom HTTP headers (including X-FitLog-Proxy-Secret).
//

import Foundation

enum FormGuideVideoClipError: LocalizedError, Equatable {
    case notAuthorized
    case invalidResponse
    case notVideo

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "This demonstration couldn’t be loaded."
        case .invalidResponse, .notVideo:
            return "This demonstration couldn’t be loaded. Check your connection and try again."
        }
    }
}

enum FormGuideVideoResponseValidator {
    static func validatePlayableDownload(response: URLResponse, fileURL: URL) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FormGuideVideoClipError.invalidResponse
        }
        switch http.statusCode {
        case 401, 403:
            throw FormGuideVideoClipError.notAuthorized
        case 200...299:
            break
        default:
            throw FormGuideVideoClipError.invalidResponse
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if contentType.contains("json") || contentType.contains("text/html") {
            throw FormGuideVideoClipError.notVideo
        }

        if hasISOMediaFtyp(at: fileURL) {
            return
        }
        if contentType.contains("video") || contentType.contains("mp4") || contentType.contains("octet-stream") || contentType.isEmpty {
            return
        }
        throw FormGuideVideoClipError.notVideo
    }

    static func hasISOMediaFtyp(at fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 8), prefix.count >= 8 else { return false }
        return prefix.subdata(in: 4..<8) == Data("ftyp".utf8)
    }
}

actor FormGuideVideoClipStore {
    static let shared = FormGuideVideoClipStore()

    private let session: URLSession
    private let fileManager: FileManager
    private var inFlightDownloads: [URL: Task<URL, Error>] = [:]

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func localFile(for remoteURL: URL, headers: [String: String]) async throws -> URL {
        if remoteURL.isFileURL {
            return remoteURL
        }

        let destination = try cacheDestination(for: remoteURL)
        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        if let existing = inFlightDownloads[remoteURL] {
            return try await existing.value
        }

        let task = Task {
            try await self.downloadToCache(remoteURL: remoteURL, destination: destination, headers: headers)
        }
        inFlightDownloads[remoteURL] = task
        defer { inFlightDownloads[remoteURL] = nil }
        return try await task.value
    }

    private func downloadToCache(remoteURL: URL, destination: URL, headers: [String: String]) async throws -> URL {
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let (tempURL, response) = try await session.download(for: request)
        defer {
            if fileManager.fileExists(atPath: tempURL.path) {
                try? fileManager.removeItem(at: tempURL)
            }
        }
        try FormGuideVideoResponseValidator.validatePlayableDownload(response: response, fileURL: tempURL)

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
        return destination
    }

    private func cacheDestination(for remoteURL: URL) throws -> URL {
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = caches.appending(path: "FormGuideClips", directoryHint: .isDirectory)
        let host = remoteURL.host ?? "video"
        let filename = remoteURL.lastPathComponent.isEmpty ? "clip.mp4" : remoteURL.lastPathComponent
        return folder.appending(path: "\(host)-\(filename)")
    }
}
