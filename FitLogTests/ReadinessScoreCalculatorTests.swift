//
//  ReadinessScoreCalculatorTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct ReadinessScoreCalculatorTests {

    @Test func highHRVAndSleep_producesGoodScore() {
        let inputs = ReadinessInputs(
            hrvSDNNMs: 80,
            hrvBaselineMs: 70,
            restingHeartRateBpm: 52,
            restingHeartRateBaselineBpm: 55,
            sleepHours: 7.5,
            restorativeSleepFraction: 0.4,
            recentHardSets: 10,
            typicalHardSets72h: 12
        )
        let score = ReadinessScoreCalculator.calculate(inputs: inputs, dayKey: "2026-06-28")
        #expect(score.score >= 65)
        #expect(score.band == .good || score.band == .optimal)
    }

    @Test func missingHealthData_stillReturnsScore() {
        let inputs = ReadinessInputs(
            hrvSDNNMs: nil,
            hrvBaselineMs: nil,
            restingHeartRateBpm: nil,
            restingHeartRateBaselineBpm: nil,
            sleepHours: nil,
            restorativeSleepFraction: nil,
            recentHardSets: 24,
            typicalHardSets72h: 12
        )
        let score = ReadinessScoreCalculator.calculate(inputs: inputs, dayKey: "2026-06-28")
        #expect(score.score >= 0 && score.score <= 100)
        #expect(!score.summary.isEmpty)
    }

    @Test func trainingOnlyInputs_reflectsTrainingLoadNotLow() {
        let inputs = ReadinessInputs(
            hrvSDNNMs: nil,
            hrvBaselineMs: nil,
            restingHeartRateBpm: nil,
            restingHeartRateBaselineBpm: nil,
            sleepHours: nil,
            restorativeSleepFraction: nil,
            recentHardSets: 10,
            typicalHardSets72h: 12
        )
        let score = ReadinessScoreCalculator.calculate(inputs: inputs, dayKey: "2026-06-28")
        #expect(score.score >= 45)
        #expect(score.band != .low)
        let load = score.components.first { $0.kind == .trainingLoad }
        #expect(load?.isAvailable == true)
        #expect(score.score == 75)
    }

    @Test func heavyTrainingLoad_lowersScore() {
        let inputs = ReadinessInputs(
            hrvSDNNMs: 70,
            hrvBaselineMs: 70,
            restingHeartRateBpm: 55,
            restingHeartRateBaselineBpm: 55,
            sleepHours: 7,
            restorativeSleepFraction: 0.35,
            recentHardSets: 40,
            typicalHardSets72h: 12
        )
        let score = ReadinessScoreCalculator.calculate(inputs: inputs, dayKey: "2026-06-28")
        let load = score.components.first { $0.kind == .trainingLoad }
        #expect(load?.score ?? 100 < 60)
    }
}
