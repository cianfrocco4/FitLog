//
//  BodyMetricsModels.swift
//  FitLog
//
//  Body weight + simple circumference log (not workout data; stored as JSON in Application Support).
//

import Foundation

struct BodyMetricEntry: Codable, Identifiable, Equatable {
    var id: UUID
    /// End-of-day style log; includes time if the user adjusts it.
    var date: Date
    /// Total body mass stored in pounds (same convention as barbell weights).
    var bodyWeightLb: Double?
    /// Circumferences stored in centimeters.
    var waistCm: Double?
    var chestCm: Double?
    var hipsCm: Double?
    var neckCm: Double?
    var bicepsCm: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        bodyWeightLb: Double? = nil,
        waistCm: Double? = nil,
        chestCm: Double? = nil,
        hipsCm: Double? = nil,
        neckCm: Double? = nil,
        bicepsCm: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.bodyWeightLb = bodyWeightLb
        self.waistCm = waistCm
        self.chestCm = chestCm
        self.hipsCm = hipsCm
        self.neckCm = neckCm
        self.bicepsCm = bicepsCm
    }
}

struct ProgressPhotoRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var capturedAt: Date
    /// File name only; lives under ProgressPhotos directory.
    var fileName: String

    init(id: UUID = UUID(), capturedAt: Date = Date(), fileName: String) {
        self.id = id
        self.capturedAt = capturedAt
        self.fileName = fileName
    }
}

private struct BodyMetricsFilePayload: Codable {
    var entries: [BodyMetricEntry]
}

private struct ProgressPhotosFilePayload: Codable {
    var records: [ProgressPhotoRecord]
}

// MARK: - Store

final class BodyMetricsStore {
    private let metricsURL: URL
    private let photosDirectory: URL
    private let photosIndexURL: URL

    init(baseDirectory: URL = URL.applicationSupportDirectory) {
        let root = baseDirectory.appending(path: "FitLogBody", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        metricsURL = root.appending(path: "body_metrics.json")
        photosDirectory = root.appending(path: "ProgressPhotos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        photosIndexURL = root.appending(path: "progress_photos.json")
    }

    func loadMetrics() -> [BodyMetricEntry] {
        guard let data = try? Data(contentsOf: metricsURL),
              let decoded = try? JSONDecoder().decode(BodyMetricsFilePayload.self, from: data)
        else { return [] }
        return decoded.entries.sorted { $0.date > $1.date }
    }

    func saveMetrics(_ entries: [BodyMetricEntry]) {
        let payload = BodyMetricsFilePayload(entries: entries.sorted { $0.date > $1.date })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: metricsURL, options: [.atomic])
    }

    func loadPhotoRecords() -> [ProgressPhotoRecord] {
        guard let data = try? Data(contentsOf: photosIndexURL),
              let decoded = try? JSONDecoder().decode(ProgressPhotosFilePayload.self, from: data)
        else { return [] }
        return decoded.records.sorted { $0.capturedAt > $1.capturedAt }
    }

    func savePhotoRecords(_ records: [ProgressPhotoRecord]) {
        let payload = ProgressPhotosFilePayload(records: records.sorted { $0.capturedAt > $1.capturedAt })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: photosIndexURL, options: [.atomic])
    }

    func photoFileURL(fileName: String) -> URL {
        photosDirectory.appending(path: fileName)
    }

    @discardableResult
    func savePhotoFile(id: UUID, imageData: Data) throws -> String {
        let name = "\(id.uuidString).jpg"
        let url = photoFileURL(fileName: name)
        try imageData.write(to: url, options: [.atomic])
        return name
    }

    func deletePhotoFile(fileName: String) {
        try? FileManager.default.removeItem(at: photoFileURL(fileName: fileName))
    }

    /// Clears metrics, photo index, and all progress photo files on disk.
    func eraseAll() {
        saveMetrics([])
        savePhotoRecords([])
        let files = (try? FileManager.default.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
