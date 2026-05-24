//
//  CardioTemplateLibraryTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct CardioTemplateLibraryTests {

    @Test func templates_includeQuickStartAndFullCatalog() {
        #expect(CardioTemplateLibrary.quickStart.count >= 3)
        #expect(CardioTemplateLibrary.all.count >= CardioTemplateLibrary.quickStart.count)
    }

    @Test @MainActor func resolveRows_mapsSeedExercises() {
        let library = CardioExerciseSeed.allExercises()
        let template = CardioTemplateLibrary.zone2FortyFive
        let resolved = CardioTemplateLibrary.resolveRows(template.rows, library: library)
        #expect(resolved.count == template.rows.count)
        #expect(resolved.first?.exercise.modality == .cardio)
        #expect(resolved.first?.prescription.kind == .steadyState)
    }

    @Test func metricsCalculator_formatsPrescriptionSummary() {
        let rx = CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60, targetZone: .zone2)
        let summary = CardioMetricsCalculator.prescriptionSummary(rx)
        #expect(summary.contains("Steady"))
        #expect(summary.contains("45:00"))
    }
}
