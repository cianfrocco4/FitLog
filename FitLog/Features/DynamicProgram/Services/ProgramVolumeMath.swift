//
//  ProgramVolumeMath.swift
//  FitLog
//
//  Shared planned/actual volume counting for program goals and review stats.
//

import Foundation

enum ProgramVolumeMath {
    /// Strength slots that count toward hard-set targets (excludes cardio and warm-up slots).
    static func plannedHardSets(in slots: [SplitBuilderEditableSlot], volumeMultiplier: Double = 1.0) -> Int {
        let raw = slots
            .filter { $0.modality != .cardio && !$0.isWarmUp }
            .reduce(0) { $0 + max(0, $1.sets) }
        let scaled = Double(raw) * max(0, volumeMultiplier)
        return Int(scaled.rounded())
    }

    /// Hard sets for a weekly rotation template, scaled by the block multiplier.
    static func plannedHardSets(in template: BlockWeeklyTemplate, volumeMultiplier: Double = 1.0) -> Int {
        plannedHardSets(in: template.slots, volumeMultiplier: volumeMultiplier)
    }

    /// Sum of planned hard sets across a block's weekly rotation (one week of templates).
    static func plannedWeeklyHardSets(for block: ProgramBlock) -> Int {
        let multiplier = effectiveVolumeMultiplier(for: block, weekInBlock: nil)
        return block.weeklyTemplates.reduce(0) { partial, template in
            partial + plannedHardSets(in: template, volumeMultiplier: multiplier)
        }
    }

    /// Planned cardio minutes from template cardio prescriptions (seconds → minutes, rounded).
    static func plannedCardioMinutes(in slots: [SplitBuilderEditableSlot], volumeMultiplier: Double = 1.0) -> Int {
        let seconds = slots.compactMap { slot -> Int? in
            guard slot.modality == .cardio else { return nil }
            return slot.cardioPrescription?.targetDurationSec
        }.reduce(0, +)
        let scaled = Double(seconds) / 60.0 * max(0, volumeMultiplier)
        return Int(scaled.rounded())
    }

    static func plannedWeeklyCardioMinutes(for block: ProgramBlock) -> Int {
        let multiplier = effectiveVolumeMultiplier(for: block, weekInBlock: nil)
        return block.weeklyTemplates.reduce(0) { partial, template in
            partial + plannedCardioMinutes(in: template.slots, volumeMultiplier: multiplier)
        }
    }

    /// Volume multiplier for a specific week in the block (1-based weekInBlock from PeriodizationEngine is 0-based).
    static func effectiveVolumeMultiplier(for block: ProgramBlock, weekInBlock: Int?) -> Double {
        if block.isDeloadBlock || block.focus.kind == .deload {
            return block.volumeMultiplier
        }
        if let weekInBlock, let deload = block.deloadWeekNumber, weekInBlock + 1 == deload {
            return min(block.volumeMultiplier, 0.7)
        }
        return block.volumeMultiplier
    }

    /// Actual hard sets from completed sessions (uses `LoggedSet.countsTowardVolumeTotals`).
    static func actualHardSets(in sessions: [WorkoutSession]) -> Int {
        sessions.reduce(0) { sessionTotal, session in
            sessionTotal + session.exerciseLogs.reduce(0) { logTotal, log in
                logTotal + log.loggedSets.filter(\.countsTowardVolumeTotals).count
            }
        }
    }

    /// Actual cardio minutes from completed sessions.
    static func actualCardioMinutes(in sessions: [WorkoutSession]) -> Int {
        let seconds = sessions.reduce(0) { sessionTotal, session in
            sessionTotal + session.exerciseLogs.reduce(0) { logTotal, log in
                logTotal + log.loggedSets.reduce(0) { setTotal, set in
                    guard set.countsTowardCardioTotals, let sec = set.cardioMetrics?.durationSec else {
                        return setTotal
                    }
                    return setTotal + sec
                }
            }
        }
        return Int((Double(seconds) / 60.0).rounded())
    }
}
