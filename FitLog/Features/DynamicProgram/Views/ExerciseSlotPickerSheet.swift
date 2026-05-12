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

    var body: some View {
        SlotLibraryPickerSheet(slot: slot, onSelect: onSelect)
    }
}
