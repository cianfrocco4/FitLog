//
//  SpotlightTourController.swift
//  FitLog
//

import Foundation
import Observation

@Observable
@MainActor
final class SpotlightTourController {
    private(set) var isActive = false
    private(set) var currentIndex = 0
    private(set) var steps: [SpotlightTourStep] = []
    private var queuedKind: SpotlightTourKind?

    var currentStep: SpotlightTourStep? {
        guard isActive, steps.indices.contains(currentIndex) else { return nil }
        return steps[currentIndex]
    }

    var isLastStep: Bool {
        guard !steps.isEmpty else { return true }
        return currentIndex >= steps.count - 1
    }

    var onComplete: (() -> Void)?

    /// Remember a tour until the first-run sheet dismisses (or Home has laid out).
    func queue(_ kind: SpotlightTourKind) {
        guard !isActive else { return }
        queuedKind = kind
    }

    var hasQueuedTour: Bool { queuedKind != nil }

    func startIfQueued(
        alreadyCompleted: Bool,
        hasProgram: Bool,
        hasWorkouts: Bool,
        workoutInProgress: Bool
    ) {
        guard let queued = queuedKind else { return }
        guard !alreadyCompleted else {
            queuedKind = nil
            return
        }
        // Keep the queue so the tour can start after the in-progress session ends.
        guard !workoutInProgress else { return }
        queuedKind = nil
        start(
            kind: resolvedKind(queued, hasProgram: hasProgram, hasWorkouts: hasWorkouts),
            alreadyCompleted: false,
            workoutInProgress: false
        )
    }

    func start(
        kind: SpotlightTourKind,
        alreadyCompleted: Bool,
        workoutInProgress: Bool
    ) {
        guard !alreadyCompleted else { return }
        guard !workoutInProgress else { return }
        queuedKind = nil
        steps = SpotlightTourCatalog.steps(for: kind)
        currentIndex = 0
        isActive = !steps.isEmpty
    }

    func advance() {
        guard isActive else { return }
        if isLastStep {
            complete()
        } else {
            currentIndex += 1
        }
    }

    /// Skip the current step when its chrome is not on screen.
    func skipMissingCurrentStep() {
        guard isActive else { return }
        if isLastStep {
            complete()
        } else {
            currentIndex += 1
        }
    }

    func skip() {
        complete()
    }

    func complete() {
        let wasActive = isActive
        isActive = false
        currentIndex = 0
        steps = []
        queuedKind = nil
        if wasActive {
            onComplete?()
        }
    }

    func reset() {
        isActive = false
        currentIndex = 0
        steps = []
        queuedKind = nil
    }

    private func resolvedKind(
        _ queued: SpotlightTourKind,
        hasProgram: Bool,
        hasWorkouts: Bool
    ) -> SpotlightTourKind {
        if hasProgram { return .afterProgram }
        if hasWorkouts { return .afterWorkout }
        if queued == .afterProgram || queued == .afterWorkout {
            return .explore
        }
        return queued
    }
}
