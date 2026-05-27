//
//  MigrationSnapshotExtras.swift
//  FitLog
//
//  Codable backup payloads and insert helpers for split presets, PRs, and dynamic programs.
//

import Foundation
import SwiftData
import os

private let extrasLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "MigrationSnapshotExtras"
)

struct BackupSplitPresetSlot: Codable, Equatable, Sendable {
    let orderIndex: Int
    let exerciseName: String
    let recommendedSets: Int
    let recommendedReps: String
}

struct BackupSplitPresetDay: Codable, Equatable, Sendable {
    let orderIndex: Int
    let dayName: String
    let slots: [BackupSplitPresetSlot]
}

struct BackupSplitPreset: Codable, Equatable, Sendable {
    let presetId: UUID
    let name: String
    let createdAt: Date
    let notes: String
    let sessionsPerWeek: Int
    let preferredWeekdays: [Int]
    let days: [BackupSplitPresetDay]
}

struct BackupPersonalRecord: Codable, Equatable, Sendable {
    let prId: UUID
    let exerciseId: UUID
    let kindRaw: String
    let value: Double
    let setId: UUID
    let sessionId: UUID
    let achievedAt: Date
}

enum MigrationSnapshotExtras {

    static func splitPresets(from rows: [SDSplitPresetV2]) -> [BackupSplitPreset] {
        rows.map { preset in
            let preferredWeekdays = (try? JSONDecoder().decode([Int].self, from: preset.preferredWeekdaysData)) ?? []
            let days = preset.days.sorted { $0.orderIndex < $1.orderIndex }.map { day in
                BackupSplitPresetDay(
                    orderIndex: day.orderIndex,
                    dayName: day.dayName,
                    slots: day.slots.sorted { $0.orderIndex < $1.orderIndex }.map { slot in
                        BackupSplitPresetSlot(
                            orderIndex: slot.orderIndex,
                            exerciseName: slot.exerciseName,
                            recommendedSets: slot.recommendedSets,
                            recommendedReps: slot.recommendedReps
                        )
                    }
                )
            }
            return BackupSplitPreset(
                presetId: preset.presetId,
                name: preset.name,
                createdAt: preset.createdAt,
                notes: preset.notes,
                sessionsPerWeek: preset.sessionsPerWeek,
                preferredWeekdays: preferredWeekdays,
                days: days
            )
        }
    }

    static func personalRecords(from rows: [SDPersonalRecordV2]) -> [BackupPersonalRecord] {
        rows.map {
            BackupPersonalRecord(
                prId: $0.prId,
                exerciseId: $0.exerciseId,
                kindRaw: $0.kindRaw,
                value: $0.value,
                setId: $0.setId,
                sessionId: $0.sessionId,
                achievedAt: $0.achievedAt
            )
        }
    }

    static func dynamicProgram(from rows: [SDDynamicProgramV2]) -> DynamicProgramState? {
        rows.first(where: { $0.isActive })?.toDomain() ?? rows.first?.toDomain()
    }

    static func insertSplitPresets(_ presets: [BackupSplitPreset], into context: ModelContext) {
        for preset in presets {
            let row = SDSplitPresetV2(
                presetId: preset.presetId,
                name: preset.name,
                createdAt: preset.createdAt,
                notes: preset.notes,
                sessionsPerWeek: preset.sessionsPerWeek
            )
            row.preferredWeekdaysData = (try? JSONEncoder().encode(preset.preferredWeekdays)) ?? Data()
            for dayData in preset.days {
                let day = SDSplitPresetDayV2(orderIndex: dayData.orderIndex, dayName: dayData.dayName)
                day.preset = row
                for slotData in dayData.slots {
                    let slot = SDSplitPresetSlotV2(
                        orderIndex: slotData.orderIndex,
                        exerciseName: slotData.exerciseName,
                        recommendedSets: slotData.recommendedSets,
                        recommendedReps: slotData.recommendedReps
                    )
                    slot.day = day
                    day.slots.append(slot)
                    context.insert(slot)
                }
                row.days.append(day)
                context.insert(day)
            }
            context.insert(row)
        }
    }

    static func insertPersonalRecords(_ records: [BackupPersonalRecord], into context: ModelContext) {
        for record in records {
            context.insert(
                SDPersonalRecordV2(
                    prId: record.prId,
                    exerciseId: record.exerciseId,
                    kindRaw: record.kindRaw,
                    value: record.value,
                    setId: record.setId,
                    sessionId: record.sessionId,
                    achievedAt: record.achievedAt
                )
            )
        }
    }

    static func insertDynamicProgram(_ state: DynamicProgramState?, into context: ModelContext) {
        guard let state else { return }
        context.insert(SDDynamicProgramV2.from(state))
    }

    static func insertExtendedSnapshotData(_ snapshot: BackupSnapshot, into context: ModelContext) {
        if !snapshot.splitPresets.isEmpty {
            insertSplitPresets(snapshot.splitPresets, into: context)
        }
        if !snapshot.personalRecords.isEmpty {
            insertPersonalRecords(snapshot.personalRecords, into: context)
        }
        insertDynamicProgram(snapshot.dynamicProgram, into: context)
        extrasLog.notice(
            "Extended snapshot inserted (presets=\(snapshot.splitPresets.count), prs=\(snapshot.personalRecords.count), dynamicProgram=\(snapshot.dynamicProgram != nil))"
        )
    }
}
