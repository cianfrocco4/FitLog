//
//  ExerciseSlotPickerSheet.swift
//  FitLog
//
//  Thin wrapper around the split-builder library picker for program slots.
//

import SwiftUI

struct ExerciseSlotPickerSheet: View {
    let slot: SplitBuilderEditableSlot
    let onSelect: (Exercise) -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        SlotLibraryPickerSheet(slot: slot, onSelect: onSelect)
            .safeAreaInset(edge: .bottom) {
                if let lastLoad = resolvedLastLoadCaption {
                    Text(lastLoad)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.bar)
                        .accessibilityIdentifier(FitLogA11yID.exerciseSlotPicker.lastLoad)
                        .accessibilityLabel(lastLoad)
                        .accessibilityHint("Last working set or last cardio duration from a completed session")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
    }

    /// Linked slot exercise when it has history; otherwise newest completed working set or cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return MossLastWorkingLoad.caption(
            forSlot: slot,
            from: dataManager.completedSessions,
            library: dataManager.globalExercises,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("Light") {
    ExerciseSlotPickerSheet(
        slot: SplitBuilderEditableSlot(
            label: "Chest",
            targetMuscleNames: ["Chest"],
            sets: 3,
            reps: "8",
            suggestedExerciseName: "Bench Press"
        ),
        onSelect: { _ in },
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
}

#Preview("Dark") {
    ExerciseSlotPickerSheet(
        slot: SplitBuilderEditableSlot(
            label: "Zone 2",
            targetMuscleNames: ["Other"],
            sets: 1,
            reps: "45:00",
            suggestedExerciseName: "Zone 2"
        ),
        onSelect: { _ in },
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
    .preferredColorScheme(.dark)
}
