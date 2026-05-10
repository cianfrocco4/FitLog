//
//  SessionDurationBuckets.swift
//  FitLog
//
//  Single source of truth for session-length ↔ minutes ↔ picker label (program builder + prefs).
//

import Foundation

enum SessionDurationBuckets {
    /// Canonical minute buckets used when encoding `sessionDurationMinutes` for AI / prefs.
    static func minutes(fromPickerLabel raw: String) -> Int? {
        switch raw {
        case "No preference": return nil
        case "~30 minutes per session": return 30
        case "~45 minutes per session": return 45
        case "~60 minutes per session": return 60
        case "~75 minutes per session": return 75
        case "~90+ minutes per session": return 90
        default: return nil
        }
    }

    static func pickerLabel(fromMinutes m: Int?) -> String {
        guard let m else { return "No preference" }
        // Map by midpoints between canonical buckets (30, 45, 60, 75, 90) so stored
        // exact values like 45/60 round-trip with the picker instead of drifting up a bucket.
        switch m {
        case ...37: return "~30 minutes per session"
        case 38 ... 52: return "~45 minutes per session"
        case 53 ... 67: return "~60 minutes per session"
        case 68 ... 82: return "~75 minutes per session"
        default: return "~90+ minutes per session"
        }
    }
}
