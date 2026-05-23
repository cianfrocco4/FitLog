//
//  PRKind.swift
//  FitLog
//
//  Kept separate from @Model types so SwiftData macro expansion does not see
//  extra type declarations in the same file as SDPersonalRecordV2.
//

import Foundation

/// The kind of personal record tracked.
enum PRKind: String, Codable, CaseIterable {
    case maxWeight
    case estimatedOneRM
    case maxVolume
    case maxDistance
    case bestPace
    case longestDuration
    case maxCalories
}
