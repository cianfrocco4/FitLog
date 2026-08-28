//
//  ReadinessInputs.swift
//  FitLog
//

import Foundation

struct ReadinessInputs: Equatable, Sendable {
    /// Most recent overnight HRV SDNN (ms).
    var hrvSDNNMs: Double?
    /// 28-day rolling median HRV (ms).
    var hrvBaselineMs: Double?

    /// Most recent resting heart rate (bpm).
    var restingHeartRateBpm: Double?
    /// 28-day rolling median resting HR (bpm).
    var restingHeartRateBaselineBpm: Double?

    /// Last night's total sleep duration (hours).
    var sleepHours: Double?
    /// Fraction of sleep in deep + REM (0...1) when available.
    var restorativeSleepFraction: Double?

    /// Hard sets logged in the last 72 hours (working / drop / failure / AMRAP with reps).
    var recentHardSets: Int
    /// Typical hard sets in a 72h window from the last 28 days.
    var typicalHardSets72h: Double

    static let empty = ReadinessInputs(
        hrvSDNNMs: nil,
        hrvBaselineMs: nil,
        restingHeartRateBpm: nil,
        restingHeartRateBaselineBpm: nil,
        sleepHours: nil,
        restorativeSleepFraction: nil,
        recentHardSets: 0,
        typicalHardSets72h: 12
    )

    /// True when Apple Health returned at least one recovery metric (read auth is intentionally opaque).
    var hasAnyHealthKitMetric: Bool {
        hrvSDNNMs != nil
            || hrvBaselineMs != nil
            || restingHeartRateBpm != nil
            || restingHeartRateBaselineBpm != nil
            || sleepHours != nil
    }
}
