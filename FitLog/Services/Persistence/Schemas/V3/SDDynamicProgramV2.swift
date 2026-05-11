//
//  SDDynamicProgramV2.swift
//  FitLog
//
//  Persists `DynamicProgramState` as a versioned JSON blob (single active row pattern).
//

import Foundation
import SwiftData

@Model
final class SDDynamicProgramV2 {
    /// `VersionedPayload<DynamicProgramState>` or raw `DynamicProgramState` JSON.
    var stateData: Data = Data()
    /// When true, this row is the active program; at most one should be true (enforced in store).
    var isActive: Bool = false

    init() {}

    func toDomain() -> DynamicProgramState? {
        versionedDecode(DynamicProgramState.self, from: stateData)
    }

    static func from(_ state: DynamicProgramState) -> SDDynamicProgramV2 {
        let row = SDDynamicProgramV2()
        row.stateData = versionedEncode(state)
        row.isActive = true
        return row
    }
}
