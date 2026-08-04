//
//  HealthKitSyncService.swift
//  FitLog
//
//  Lightweight wrapper for Apple Health authorization + workout writes.
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthSyncAuthorizationState: String {
    case unavailable
    case notDetermined
    case denied
    case authorized
}

enum HealthKitSyncError: LocalizedError {
    case unavailable
    case notAuthorized
    case workoutHasNoEndTime
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .notAuthorized:
            return "Apple Health permission has not been granted."
        case .workoutHasNoEndTime:
            return "Workout has no end time and cannot be synced."
        case .saveFailed(let message):
            return "Failed to save workout to Apple Health: \(message)"
        }
    }
}

final class HealthKitSyncService {
#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
#endif
    private static let syncEnabledKey = "fitlog.health.sync.enabled"

    var syncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.syncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.syncEnabledKey) }
    }

    var statusMessage: String? {
        switch authorizationState() {
        case .unavailable:
            return "Apple Health is unavailable on this device."
        case .notDetermined:
            return "Health permission not requested yet."
        case .denied:
            return "Health permission denied. Enable access in Health settings."
        case .authorized:
            return "Connected to Apple Health."
        }
    }

    func authorizationState() -> HealthSyncAuthorizationState {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        if requiredWriteTypes().contains(where: { healthStore.authorizationStatus(for: $0) == .sharingDenied }) {
            return .denied
        }
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        switch workoutStatus {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            if needsAuthorizationUpgrade() {
                return .notDetermined
            }
            return .authorized
        @unknown default:
            return .notDetermined
        }
#else
        return .unavailable
#endif
    }

    private func requiredWriteTypes() -> [HKSampleType] {
#if canImport(HealthKit)
        var types: [HKSampleType] = [HKObjectType.workoutType()]
        for identifier in [
            HKQuantityTypeIdentifier.distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .distanceRowing
        ] {
            if let distance = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.append(distance)
            }
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.append(energy)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.append(heartRate)
        }
        return types
#else
        return []
#endif
    }

    private func needsAuthorizationUpgrade() -> Bool {
#if canImport(HealthKit)
        requiredWriteTypes().contains { healthStore.authorizationStatus(for: $0) == .notDetermined }
#else
        return false
#endif
    }

    func requestAuthorization() async -> Bool {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let toShare = Set(requiredWriteTypes())
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: toShare, read: [HKObjectType.workoutType()]) { success, _ in
                continuation.resume(returning: success)
            }
        }
#else
        return false
#endif
    }

    @MainActor
    func setSyncEnabled(_ enabled: Bool) async -> Bool {
        if !enabled {
            syncEnabled = false
            return false
        }
        if authorizationState() == .authorized {
            syncEnabled = true
            return true
        }
        let granted = await requestAuthorization()
        let fullyAuthorized = authorizationState() == .authorized
        syncEnabled = granted && fullyAuthorized
        return syncEnabled
    }

    func saveCompletedSession(_ session: WorkoutSession, exercises: [Exercise]) async throws {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitSyncError.unavailable
        }
        guard authorizationState() == .authorized else {
            throw HealthKitSyncError.notAuthorized
        }
        guard let end = session.endTime else {
            throw HealthKitSyncError.workoutHasNoEndTime
        }

        let aggregates = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: exercises)
        let activityType = CardioHealthKitMapping.workoutActivityType(for: session, exercises: exercises)
        let indoor = CardioHealthKitMapping.isIndoorWorkout(session: session, exercises: exercises)

        let metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: AppBrand.name,
            HKMetadataKeyIndoorWorkout: indoor,
            "fitlog_workout_name": session.workout.name,
            "fitlog_workout_session_id": session.id.uuidString,
            "fitlog_workout_kind": session.workout.workoutKind.rawValue
        ]

        let duration = max(0, end.timeIntervalSince(session.startTime))
        let energy: HKQuantity? = {
            guard aggregates.calories > 0,
                  HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) != nil
            else { return nil }
            return HKQuantity(unit: .kilocalorie(), doubleValue: aggregates.calories)
        }()
        let distance: HKQuantity? = {
            guard aggregates.distanceMeters > 0,
                  CardioHealthKitMapping.distanceQuantityType(for: aggregates.dominantActivityKind) != nil
            else { return nil }
            return HKQuantity(unit: .meter(), doubleValue: aggregates.distanceMeters)
        }()

        let workout = HKWorkout(
            activityType: activityType,
            start: session.startTime,
            end: end,
            duration: duration,
            totalEnergyBurned: energy,
            totalDistance: distance,
            metadata: metadata
        )

        var hrSamples: [HKSample] = []
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            for log in session.exerciseLogs {
                for set in log.loggedSets where set.countsTowardCardioTotals {
                    guard let bpm = set.cardioMetrics?.avgHeartRate, bpm > 0 else { continue }
                    let qty = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(bpm))
                    let sample = HKQuantitySample(
                        type: hrType,
                        quantity: qty,
                        start: set.timestamp,
                        end: set.timestamp.addingTimeInterval(1)
                    )
                    hrSamples.append(sample)
                }
            }
        }

        try await withCheckedThrowingContinuation { [healthStore] (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
                guard success else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    continuation.resume(throwing: HealthKitSyncError.saveFailed(message))
                    return
                }
                guard !hrSamples.isEmpty else {
                    continuation.resume()
                    return
                }
                healthStore.add(hrSamples, to: workout) { added, addError in
                    if added {
                        continuation.resume()
                    } else {
                        #if DEBUG
                        let message = addError?.localizedDescription ?? "Unknown error"
                        print("[HealthKit] Workout saved but heart-rate attach failed: \(message)")
                        #endif
                        continuation.resume()
                    }
                }
            }
        }
#else
        throw HealthKitSyncError.unavailable
#endif
    }

    func writeWorkoutIfAuthorized(session: WorkoutSession, exercises: [Exercise]) async {
        guard syncEnabled else { return }
        guard authorizationState() == .authorized else { return }
        _ = try? await saveCompletedSession(session, exercises: exercises)
    }

    /// Read access for body mass (separate from workout write permission).
    func requestBodyMassReadAccess() async -> Bool {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: [bodyMass]) { success, _ in
                continuation.resume(returning: success)
            }
        }
#else
        return false
#endif
    }

    /// Most recent body mass sample in pounds, if read access allows.
    func fetchLatestBodyMassLb() async -> Double? {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMass,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let lb = sample.quantity.doubleValue(for: HKUnit.pound())
                continuation.resume(returning: lb)
            }
            healthStore.execute(query)
        }
#else
        return nil
#endif
    }
}

