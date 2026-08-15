//
//  PreviousSessionPrefillAccessibility.swift
//  FitLog
//

import Foundation

enum PreviousSessionPrefillAccessibility {
    static func pillLabel(weightDisplay: String, unitLabel: String, reps: Int) -> String {
        "Use previous set \(weightDisplay) \(unitLabel) × \(reps)"
    }

    static var pillHint: String {
        "Fills weight and reps for the next set"
    }
}
