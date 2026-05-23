//
//  SDSchemaMigrationAnchorV4.swift
//  FitLog
//
//  V4-only entity so `FitLogSchemaV4` has a distinct version checksum from frozen `FitLogSchemaV3`.
//  Cardio columns on existing types use inline defaults (lightweight); without a V4-only model,
//  SwiftData can report "Duplicate version checksums detected." for V3 and V4.
//

import Foundation
import SwiftData

@Model
final class SDSchemaMigrationAnchorV4 {
    /// Marker row for schema 4.0.0; at most one row is expected after V3→V4 migration.
    var schemaVersionMajor: Int = 4

    init() {}
}
