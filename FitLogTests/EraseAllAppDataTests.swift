//
//  EraseAllAppDataTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite(.serialized)
struct EraseAllAppDataTests {

    @Test @MainActor func eraseAllAppData_removesCoachAndReadiness() throws {
        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)

        let conversationID = dm.coachChatStore.createConversation(title: "Erase me")
        #expect(dm.coachChatStore.appendMessage(
            CoachChatMessage(role: .user, text: "Hello coach"),
            conversationID: conversationID
        ))

        let score = ReadinessScore(
            id: UUID(),
            dayKey: "2026-07-26",
            computedAt: Date(),
            score: 72,
            band: .good,
            summary: "Good day",
            components: []
        )
        try dm.readinessStore.upsert(score)
        #expect(dm.readinessStore.load(dayKey: "2026-07-26")?.score == 72)
        #expect(!dm.coachChatStore.loadConversations().isEmpty)

        UserDefaults.standard.set(Data([0x01, 0x02]), forKey: "activeWorkoutSession")
        dm.eraseAllAppData()

        #expect(dm.coachChatStore.loadConversations().isEmpty)
        #expect(dm.readinessStore.load(dayKey: "2026-07-26") == nil)
        #expect(dm.bodyMetricEntries.isEmpty)
        #expect(dm.progressPhotoRecords.isEmpty)
        #expect(UserDefaults.standard.data(forKey: "activeWorkoutSession") == nil)
        #expect(!dm.globalExercises.isEmpty)
    }

    @Test func bodyMetricsStore_eraseAll_deletesPhotoFilesOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appending(
            path: "FitLogBodyErase_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BodyMetricsStore(baseDirectory: dir)
        let photoID = UUID()
        let fileName = try store.savePhotoFile(id: photoID, imageData: Data([0xFF, 0xD8, 0xFF]))
        store.savePhotoRecords([
            ProgressPhotoRecord(id: photoID, capturedAt: Date(), fileName: fileName)
        ])
        store.saveMetrics([
            BodyMetricEntry(id: UUID(), date: Date(), bodyWeightLb: 180)
        ])

        #expect(FileManager.default.fileExists(atPath: store.photoFileURL(fileName: fileName).path))

        store.eraseAll()

        #expect(store.loadMetrics().isEmpty)
        #expect(store.loadPhotoRecords().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.photoFileURL(fileName: fileName).path))
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
