//
//  SplitBuilderPreferencesStore.swift
//  FitLog
//
//  Persists **wizard defaults only** for the AI split builder (UserDefaults JSON).
//  This does **not** replace SwiftData workout/program data — it only pre-fills the
//  builder so repeat visits are faster.
//
//  ## Migration policy
//  - Storage key is version-suffixed: `fitlog.splitBuilder.wizardEnvelope.v1`.
//  - Each write wraps payload in `{ "schemaVersion": N, ... }`.
//  - On read: decode `schemaVersion` first; branch and migrate older shapes in code.
//  - Never reuse a key for an incompatible JSON shape — add `...v2` key if a breaking
//    change cannot be migrated safely, and copy forward from v1 once.
//  - If decoding fails entirely, return `.default` (user keeps all app data; only
//    builder pre-fill resets).
//

import Foundation

enum SplitBuilderPreferencesStore {

    /// Bump when adding non-optional fields or changing semantics; implement migration from previous.
    private static let currentSchemaVersion = 6
    private static let envelopeKey = "fitlog.splitBuilder.wizardEnvelope.v1"

    struct State: Equatable {
        var primaryGoalRaw: String?
        var equipmentRaw: String?
        var splitPreferenceRaw: String?
        var experienceRaw: String?
        var sessionsPerWeek: Int?
        var selectedWeekdayNumbers: [Int]?
        var updateTrainingProgram: Bool?
        var limitationsNotes: String?
        var additionalNotes: String?
        var sessionDurationRaw: String?
        var intensityStyleRaw: String?
        var progressionStyleRaw: String?
        var priorityMusclesOrLiftsNotes: String?
        var recoveryContextNotes: String?
        var deloadPreferenceRaw: String?
        var cardioPreferenceRaw: String?
        var cardioGoalRaw: String?
        var cardioDedicatedDayCount: Int?
        var cardioFinisherDurationMinutes: Int?
        var cardioFinisherZoneRaw: Int?
        var cardioWeeklyProgressionMinutes: Int?
        var variationModeRaw: String?
        var customRotationLength: Int?
        var variationNotes: String?
        /// Dynamic / periodized program builder extras (optional for backward compatibility).
        var programName: String?
        var isPeriodizedProgram: Bool?
        var busyDayPolicyRaw: String?
        /// JSON array of `PersistedDynamicBlockSpec` for wizard block rows.
        var dynamicBlockSpecsJSON: String?
        /// `"ai"` or `"manual"` for unified program builder mode.
        var programBuilderModeRaw: String?
        /// Last selected program builder entry route (`guidedCoach`, `templates`, `advancedBuilder`).
        var programBuilderEntryRouteRaw: String?

        static let `default` = State(
            primaryGoalRaw: nil,
            equipmentRaw: nil,
            splitPreferenceRaw: nil,
            experienceRaw: nil,
            sessionsPerWeek: nil,
            selectedWeekdayNumbers: nil,
            updateTrainingProgram: nil,
            limitationsNotes: nil,
            additionalNotes: nil,
            sessionDurationRaw: nil,
            intensityStyleRaw: nil,
            progressionStyleRaw: nil,
            priorityMusclesOrLiftsNotes: nil,
            recoveryContextNotes: nil,
            deloadPreferenceRaw: nil,
            cardioPreferenceRaw: nil,
            cardioGoalRaw: nil,
            cardioDedicatedDayCount: nil,
            cardioFinisherDurationMinutes: nil,
            cardioFinisherZoneRaw: nil,
            cardioWeeklyProgressionMinutes: nil,
            variationModeRaw: nil,
            customRotationLength: nil,
            variationNotes: nil,
            programName: nil,
            isPeriodizedProgram: nil,
            busyDayPolicyRaw: nil,
            dynamicBlockSpecsJSON: nil,
            programBuilderModeRaw: nil,
            programBuilderEntryRouteRaw: nil
        )
    }

    private struct EnvelopeV1: Codable, Equatable {
        var schemaVersion: Int
        var primaryGoalRaw: String?
        var equipmentRaw: String?
        var splitPreferenceRaw: String?
        var experienceRaw: String?
        var sessionsPerWeek: Int?
        var selectedWeekdayNumbers: [Int]?
        var updateTrainingProgram: Bool?
        var limitationsNotes: String?
        var additionalNotes: String?
        var sessionDurationRaw: String?
        var intensityStyleRaw: String?
        var progressionStyleRaw: String?
        var priorityMusclesOrLiftsNotes: String?
        var recoveryContextNotes: String?
        var deloadPreferenceRaw: String?
        var cardioPreferenceRaw: String?
        var cardioGoalRaw: String?
        var cardioDedicatedDayCount: Int?
        var cardioFinisherDurationMinutes: Int?
        var cardioFinisherZoneRaw: Int?
        var cardioWeeklyProgressionMinutes: Int?
        var variationModeRaw: String?
        var customRotationLength: Int?
        var variationNotes: String?
        var programName: String?
        var isPeriodizedProgram: Bool?
        var busyDayPolicyRaw: String?
        var dynamicBlockSpecsJSON: String?
        var programBuilderModeRaw: String?
        var programBuilderEntryRouteRaw: String?
    }

    static func load() -> State {
        guard let data = UserDefaults.standard.data(forKey: envelopeKey) else { return .default }
        let dec = JSONDecoder()
        guard let env = try? dec.decode(EnvelopeV1.self, from: data) else { return .default }
        switch env.schemaVersion {
        case 1, 2, 3, 4, 5, 6:
            return State(
                primaryGoalRaw: env.primaryGoalRaw,
                equipmentRaw: env.equipmentRaw,
                splitPreferenceRaw: env.splitPreferenceRaw,
                experienceRaw: env.experienceRaw,
                sessionsPerWeek: env.sessionsPerWeek,
                selectedWeekdayNumbers: env.selectedWeekdayNumbers,
                updateTrainingProgram: env.updateTrainingProgram,
                limitationsNotes: env.limitationsNotes,
                additionalNotes: env.additionalNotes,
                sessionDurationRaw: env.sessionDurationRaw,
                intensityStyleRaw: env.intensityStyleRaw,
                progressionStyleRaw: env.progressionStyleRaw,
                priorityMusclesOrLiftsNotes: env.priorityMusclesOrLiftsNotes,
                recoveryContextNotes: env.recoveryContextNotes,
                deloadPreferenceRaw: env.deloadPreferenceRaw,
                cardioPreferenceRaw: env.cardioPreferenceRaw,
                cardioGoalRaw: env.cardioGoalRaw,
                cardioDedicatedDayCount: env.cardioDedicatedDayCount,
                cardioFinisherDurationMinutes: env.cardioFinisherDurationMinutes,
                cardioFinisherZoneRaw: env.cardioFinisherZoneRaw,
                cardioWeeklyProgressionMinutes: env.cardioWeeklyProgressionMinutes,
                variationModeRaw: env.variationModeRaw,
                customRotationLength: env.customRotationLength,
                variationNotes: env.variationNotes,
                programName: env.programName,
                isPeriodizedProgram: env.isPeriodizedProgram,
                busyDayPolicyRaw: env.busyDayPolicyRaw,
                dynamicBlockSpecsJSON: env.dynamicBlockSpecsJSON,
                programBuilderModeRaw: env.programBuilderModeRaw,
                programBuilderEntryRouteRaw: env.programBuilderEntryRouteRaw
            )
        default:
            // Future: migrate from unknown version or legacy keys
            return .default
        }
    }

    static func save(_ state: State) {
        let env = EnvelopeV1(
            schemaVersion: currentSchemaVersion,
            primaryGoalRaw: state.primaryGoalRaw,
            equipmentRaw: state.equipmentRaw,
            splitPreferenceRaw: state.splitPreferenceRaw,
            experienceRaw: state.experienceRaw,
            sessionsPerWeek: state.sessionsPerWeek,
            selectedWeekdayNumbers: state.selectedWeekdayNumbers,
            updateTrainingProgram: state.updateTrainingProgram,
            limitationsNotes: state.limitationsNotes,
            additionalNotes: state.additionalNotes,
            sessionDurationRaw: state.sessionDurationRaw,
            intensityStyleRaw: state.intensityStyleRaw,
            progressionStyleRaw: state.progressionStyleRaw,
            priorityMusclesOrLiftsNotes: state.priorityMusclesOrLiftsNotes,
            recoveryContextNotes: state.recoveryContextNotes,
            deloadPreferenceRaw: state.deloadPreferenceRaw,
            cardioPreferenceRaw: state.cardioPreferenceRaw,
            cardioGoalRaw: state.cardioGoalRaw,
            cardioDedicatedDayCount: state.cardioDedicatedDayCount,
            cardioFinisherDurationMinutes: state.cardioFinisherDurationMinutes,
            cardioFinisherZoneRaw: state.cardioFinisherZoneRaw,
            cardioWeeklyProgressionMinutes: state.cardioWeeklyProgressionMinutes,
            variationModeRaw: state.variationModeRaw,
            customRotationLength: state.customRotationLength,
            variationNotes: state.variationNotes,
            programName: state.programName,
            isPeriodizedProgram: state.isPeriodizedProgram,
            busyDayPolicyRaw: state.busyDayPolicyRaw,
            dynamicBlockSpecsJSON: state.dynamicBlockSpecsJSON,
            programBuilderModeRaw: state.programBuilderModeRaw,
            programBuilderEntryRouteRaw: state.programBuilderEntryRouteRaw
        )
        guard let data = try? JSONEncoder().encode(env) else { return }
        UserDefaults.standard.set(data, forKey: envelopeKey)
    }
}
