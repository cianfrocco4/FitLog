//
//  CardioMetricsCalculator.swift
//  FitLog
//
//  Formatting helpers for cardio prescriptions and metrics display.
//

import Foundation

enum CardioMetricsCalculator {

    static func formatDuration(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    /// VoiceOver-friendly duration (e.g. "12 minutes, 34 seconds").
    static func spokenDuration(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        var parts: [String] = []
        if h > 0 {
            parts.append("\(h) hour\(h == 1 ? "" : "s")")
        }
        if m > 0 {
            parts.append("\(m) minute\(m == 1 ? "" : "s")")
        }
        if sec > 0 || parts.isEmpty {
            parts.append("\(sec) second\(sec == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    static func formatDistance(meters: Double) -> String {
        let m = max(0, meters)
        if m >= 1000 {
            let km = m / 1000
            return String(format: "%.2f km", km)
        }
        return String(format: "%.0f m", m)
    }

    static func formatPace(secPerKm: Int) -> String {
        let pace = max(0, secPerKm)
        let m = pace / 60
        let s = pace % 60
        return String(format: "%d:%02d /km", m, s)
    }

    /// Single-line summary for builder rows and workout plan.
    static func prescriptionSummary(_ prescription: CardioPrescription) -> String {
        switch prescription.kind {
        case .steadyState:
            var parts: [String] = ["Steady"]
            if let sec = prescription.targetDurationSec, sec > 0 {
                parts.append(formatDuration(seconds: sec))
            }
            if let m = prescription.targetDistanceM, m > 0 {
                parts.append(formatDistance(meters: m))
            }
            if let pace = prescription.targetPaceSecPerKm {
                parts.append(formatPace(secPerKm: pace))
            }
            if let zone = prescription.targetZone {
                parts.append(zone.displayName)
            }
            return parts.joined(separator: " · ")

        case .intervals:
            let totalRepeats = prescription.intervals.reduce(0) { $0 + max(1, $1.repeatCount) }
            if let spec = prescription.intervals.first {
                var parts: [String] = ["\(totalRepeats)× intervals"]
                if let work = spec.workDurationSec {
                    parts.append("\(work)s work")
                } else if let dist = spec.workDistanceM {
                    parts.append(formatDistance(meters: dist))
                }
                if let rest = spec.restDurationSec, rest > 0 {
                    parts.append("\(rest)s rest")
                }
                return parts.joined(separator: " · ")
            }
            return "Intervals · \(totalRepeats) rounds"

        case .circuit:
            if let sec = prescription.targetDurationSec {
                return "Circuit · \(formatDuration(seconds: sec))"
            }
            return "Circuit"

        case .custom:
            let note = prescription.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return note.isEmpty ? "Custom cardio" : note
        }
    }
}
