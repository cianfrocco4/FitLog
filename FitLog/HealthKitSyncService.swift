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
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
#else
        return .unavailable
#endif
    }

    func requestAuthorization() async -> Bool {
#if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
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
        syncEnabled = granted
        return granted
    }

    func saveCompletedSession(_ session: WorkoutSession) async throws {
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

        let metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "The Workout Log",
            HKMetadataKeyIndoorWorkout: true,
            "fitlog_workout_name": session.workout.name,
            "fitlog_workout_session_id": session.id.uuidString
        ]

        let duration = max(0, end.timeIntervalSince(session.startTime))
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: session.startTime,
            end: end,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )

        try await withCheckedThrowingContinuation { continuation in
            healthStore.save(workout) { success, error in
                if success {
                    continuation.resume()
                } else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    continuation.resume(throwing: HealthKitSyncError.saveFailed(message))
                }
            }
        }
#else
        throw HealthKitSyncError.unavailable
#endif
    }

    func writeWorkoutIfAuthorized(session: WorkoutSession) async {
        guard syncEnabled else { return }
        guard authorizationState() == .authorized else { return }
        _ = try? await saveCompletedSession(session)
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

