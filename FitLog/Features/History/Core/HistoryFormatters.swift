//
//  HistoryFormatters.swift
//  FitLog
//

import Foundation

enum HistoryFormatters {
    private static let mediumDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func formatCompact(_ value: Double) -> String {
        let n = abs(value)
        if n >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if n >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        if n >= 1000 {
            return String(format: "%.2fk", value / 1000)
        }
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    static func formatCompactInt(_ value: Int) -> String {
        formatCompact(Double(value))
    }

    static func epleyEst1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    static func rpeLabel(_ rpe: Double) -> String {
        if abs(rpe.truncatingRemainder(dividingBy: 1)) < 0.001 {
            return "RPE \(Int(rpe))"
        }
        return String(format: "RPE %.1f", rpe)
    }

    static func formatDateTime(_ date: Date) -> String {
        mediumDateTimeFormatter.string(from: date)
    }

    static func formatMediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    static func formatAvgDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let m = seconds / 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return "\(h)h \(mm)m"
        }
        return "\(m)m"
    }

    static func durationString(for session: WorkoutSession) -> String {
        let end = session.endTime ?? session.startTime
        let secs = Int(end.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    @MainActor
    static func templateSlotCaption(for log: ExerciseLog, session: WorkoutSession, dataVM: DataManager) -> String? {
        guard case .workout(let libraryId) = session.sessionPlanOrigin,
              let slotUUID = session.workout.templateSlotId(forWorkoutExerciseRow: log.workoutExercise.id),
              let lib = dataVM.workout(id: libraryId),
              lib.hasFlexibleSlots,
              let slot = dataVM.flexibleSlots(from: lib).first(where: { $0.id == slotUUID })
        else { return nil }
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    static func volumeUnitLabel(weightUnit: WeightDisplayUnit) -> String {
        weightUnit == .pounds ? "lb·rep" : "kg·rep"
    }

    static func volumeUnitExplanation(weightUnit: WeightDisplayUnit) -> String {
        let unit = weightUnit == .pounds ? "pounds" : "kilograms"
        return "Volume is the sum of weight × reps across all working sets in the selected range. Values are shown in \(unit)·rep."
    }
}

// MARK: - HistoryView static forwarders (external callers)

extension HistoryView {
    static func templateSlotCaption(for log: ExerciseLog, session: WorkoutSession, dataVM: DataManager) -> String? {
        HistoryFormatters.templateSlotCaption(for: log, session: session, dataVM: dataVM)
    }

    static func formatDateStatic(_ date: Date) -> String {
        HistoryFormatters.formatDateTime(date)
    }

    static func durationStringStatic(for session: WorkoutSession) -> String {
        HistoryFormatters.durationString(for: session)
    }
}
