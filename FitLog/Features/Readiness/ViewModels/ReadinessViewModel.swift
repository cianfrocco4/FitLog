//
//  ReadinessViewModel.swift
//  FitLog
//

import Foundation
import Observation

@Observable @MainActor
final class ReadinessViewModel {
    private(set) var todayScore: ReadinessScore?
    private(set) var trendScores: [ReadinessScore] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var connectState: ReadinessHealthConnectState = .hidden
    private(set) var isHealthDataAvailable = false

    private let reader = HealthMetricsReader()

    /// Refreshes readiness without prompting for HealthKit permission.
    func refresh(dataVM: DataManager, dayKey: String, userPreferences: UserPreferences) async {
        isLoading = true
        defer { isLoading = false }
        isHealthDataAvailable = reader.isHealthDataAvailable

        let trainingLoad = dataVM.trainingLoadMetrics()
        do {
            let inputs = try await fetchInputsRespectingConsent(
                trainingLoad: trainingLoad,
                userPreferences: userPreferences
            )

            let score = ReadinessScoreCalculator.calculate(inputs: inputs, dayKey: dayKey)
            todayScore = score
            errorMessage = nil
            connectState = Self.resolveConnectState(
                isHealthDataAvailable: isHealthDataAvailable,
                hasMetrics: inputs.hasAnyHealthKitMetric,
                authorizationAttempted: userPreferences.healthKitAuthorizationAttempted
            )
            try? dataVM.readinessStore.upsert(score)
            dataVM.publishWidgetSnapshot(readiness: score)
            AnalyticsService.shared.track(.readinessViewed, properties: ["score": "\(score.score)"])
        } catch {
            errorMessage = error.localizedDescription
            if let cached = dataVM.readinessStore.load(dayKey: dayKey) {
                todayScore = cached
                dataVM.publishWidgetSnapshot(readiness: cached)
            } else {
                todayScore = ReadinessScore.placeholder(dayKey: dayKey)
            }
            connectState = Self.resolveConnectState(
                isHealthDataAvailable: isHealthDataAvailable,
                hasMetrics: false,
                authorizationAttempted: userPreferences.healthKitAuthorizationAttempted
            )
        }
    }

    /// User-initiated Apple Health connection — only path that requests read authorization.
    func connectAppleHealth(dataVM: DataManager, dayKey: String, userPreferences: UserPreferences) async {
        guard reader.isHealthDataAvailable else {
            errorMessage = HealthMetricsReaderError.unavailable.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            if !userPreferences.healthKitAuthorizationAttempted {
                try await reader.requestAuthorization()
                userPreferences.healthKitAuthorizationAttempted = true
                AnalyticsService.shared.track(.readinessAuthorized)
            }
            await refresh(dataVM: dataVM, dayKey: dayKey, userPreferences: userPreferences)
        } catch {
            errorMessage = error.localizedDescription
            connectState = userPreferences.healthKitAuthorizationAttempted ? .noData : .connect
        }
    }

    func loadTrend(dataVM: DataManager, days: Int, endingDayKey: String) {
        let keys = Self.dayKeys(endingAt: endingDayKey, count: days)
        trendScores = dataVM.readinessStore.loadTrend(dayKeys: keys)
    }

    nonisolated static func dayKeys(endingAt dayKey: String, count: Int) -> [String] {
        guard count > 0 else { return [] }
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: dayKey) else { return [] }
        return (0..<count).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -(count - 1 - offset), to: endDate) else { return nil }
            return TrainingProgramState.dayKey(for: date)
        }
    }

    nonisolated static func resolveConnectState(
        isHealthDataAvailable: Bool,
        hasMetrics: Bool,
        authorizationAttempted: Bool
    ) -> ReadinessHealthConnectState {
        guard isHealthDataAvailable, !hasMetrics else { return .hidden }
        return authorizationAttempted ? .noData : .connect
    }

    private func fetchInputsRespectingConsent(
        trainingLoad: (recentHardSets: Int, typicalHardSets72h: Double),
        userPreferences: UserPreferences
    ) async throws -> ReadinessInputs {
        guard reader.isHealthDataAvailable else {
            return trainingLoadOnlyInputs(trainingLoad)
        }

        if userPreferences.healthKitAuthorizationAttempted {
            return try await reader.fetchInputs(trainingLoad: trainingLoad)
        }

        return trainingLoadOnlyInputs(trainingLoad)
    }

    private func trainingLoadOnlyInputs(
        _ trainingLoad: (recentHardSets: Int, typicalHardSets72h: Double)
    ) -> ReadinessInputs {
        ReadinessInputs(
            hrvSDNNMs: nil,
            hrvBaselineMs: nil,
            restingHeartRateBpm: nil,
            restingHeartRateBaselineBpm: nil,
            sleepHours: nil,
            restorativeSleepFraction: nil,
            recentHardSets: trainingLoad.recentHardSets,
            typicalHardSets72h: trainingLoad.typicalHardSets72h
        )
    }
}
