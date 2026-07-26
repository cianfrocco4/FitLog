//
//  HealthMetricsReader.swift
//  FitLog
//
//  Reads sleep, HRV, resting HR, and related metrics from Apple Health.
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthMetricsReaderError: LocalizedError {
    case unavailable
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Health is not available on this device."
        case .queryFailed(let detail): return "Could not read Apple Health data: \(detail)"
        }
    }
}

final class HealthMetricsReader {
#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
#endif

    var isHealthDataAvailable: Bool {
#if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
#else
        false
#endif
    }

    func requestAuthorization() async throws {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthMetricsReaderError.unavailable }
        var readTypes = Set<HKObjectType>()
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { readTypes.insert(hrv) }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { readTypes.insert(rhr) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(sleep) }
        guard !readTypes.isEmpty else { throw HealthMetricsReaderError.unavailable }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
#else
        throw HealthMetricsReaderError.unavailable
#endif
    }

    func fetchInputs(trainingLoad: (recentHardSets: Int, typicalHardSets72h: Double)) async throws -> ReadinessInputs {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthMetricsReaderError.unavailable }
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now

        async let hrvRecent = latestQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            since: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        )
        async let hrvBaseline = medianQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            from: start,
            to: now
        )
        async let rhrRecent = latestQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            since: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        )
        async let rhrBaseline = medianQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: start,
            to: now
        )
        async let sleep = latestSleepSummary()

        return ReadinessInputs(
            hrvSDNNMs: try await hrvRecent,
            hrvBaselineMs: try await hrvBaseline,
            restingHeartRateBpm: try await rhrRecent,
            restingHeartRateBaselineBpm: try await rhrBaseline,
            sleepHours: try await sleep?.hours,
            restorativeSleepFraction: try await sleep?.restorativeFraction,
            recentHardSets: trainingLoad.recentHardSets,
            typicalHardSets72h: trainingLoad.typicalHardSets72h
        )
#else
        throw HealthMetricsReaderError.unavailable
#endif
    }

#if canImport(HealthKit)
    private struct SleepSummary {
        let hours: Double
        let restorativeFraction: Double
    }

    private func latestQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthMetricsReaderError.queryFailed(error.localizedDescription))
                    return
                }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func medianQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthMetricsReaderError.queryFailed(error.localizedDescription))
                    return
                }
                let values = (samples as? [HKQuantitySample] ?? []).map { $0.quantity.doubleValue(for: unit) }.sorted()
                guard !values.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let mid = values.count / 2
                if values.count.isMultiple(of: 2) {
                    continuation.resume(returning: (values[mid - 1] + values[mid]) / 2)
                } else {
                    continuation.resume(returning: values[mid])
                }
            }
            healthStore.execute(query)
        }
    }

    private func latestSleepSummary() async throws -> SleepSummary? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -36, to: end) ?? end
        let categories = try await sleepSamples(from: sleepType, start: start, end: end)
        let asleepSamples = categories.filter { Self.isAsleep($0.value) }
        guard !asleepSamples.isEmpty else { return nil }

        let metrics = Self.mostRecentSleepSessionMetrics(from: asleepSamples)
        guard metrics.asleepSeconds > 0 else { return nil }

        return SleepSummary(
            hours: metrics.asleepSeconds / 3600,
            restorativeFraction: metrics.restorativeSeconds / metrics.asleepSeconds
        )
    }

    private func sleepSamples(from sleepType: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthMetricsReaderError.queryFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private struct SleepSessionMetrics {
        let asleepSeconds: Double
        let restorativeSeconds: Double
    }

    private struct SleepInterval {
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    private static func mostRecentSleepSessionMetrics(from samples: [HKCategorySample]) -> SleepSessionMetrics {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var merged: [SleepInterval] = []
        for sample in sorted {
            let interval = SleepInterval(start: sample.startDate, end: sample.endDate)
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = SleepInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        let sessionGap: TimeInterval = 3 * 3600
        var sessions: [[SleepInterval]] = []
        var current: [SleepInterval] = []
        for interval in merged {
            if let last = current.last, interval.start.timeIntervalSince(last.end) > sessionGap {
                sessions.append(current)
                current = [interval]
            } else {
                current.append(interval)
            }
        }
        if !current.isEmpty {
            sessions.append(current)
        }

        guard !sessions.isEmpty else {
            return SleepSessionMetrics(asleepSeconds: 0, restorativeSeconds: 0)
        }

        let longestSession = sessions.max { lhs, rhs in
            let lhsDuration = lhs.reduce(0) { $0 + $1.duration }
            let rhsDuration = rhs.reduce(0) { $0 + $1.duration }
            return lhsDuration < rhsDuration
        } ?? sessions[sessions.count - 1]

        let sessionStart = longestSession.first?.start ?? .distantPast
        let sessionEnd = longestSession.last?.end ?? .distantPast
        let asleepSeconds = longestSession.reduce(0) { $0 + $1.duration }
        var restorativeSeconds = 0.0

        for sample in sorted where Self.isRestorative(sample.value) {
            let overlapStart = max(sample.startDate, sessionStart)
            let overlapEnd = min(sample.endDate, sessionEnd)
            guard overlapEnd > overlapStart else { continue }
            restorativeSeconds += overlapEnd.timeIntervalSince(overlapStart)
        }

        return SleepSessionMetrics(asleepSeconds: asleepSeconds, restorativeSeconds: restorativeSeconds)
    }

    private static func isAsleep(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        return value == HKCategoryValueSleepAnalysis.asleep.rawValue
    }

    private static func isRestorative(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        return false
    }
#endif
}
