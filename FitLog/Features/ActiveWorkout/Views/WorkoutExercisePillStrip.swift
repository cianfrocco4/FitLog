//
//  WorkoutExercisePillStrip.swift
//  FitLog
//
//  Horizontal exercise navigation during an active workout with set progress on pills.
//

import SwiftUI

struct WorkoutExercisePillStrip: View {
    let logs: [ExerciseLog]
    @Binding var expandedExerciseIndex: Int?
    let activeExerciseIdsCount: Int
    let displayName: (WorkoutExercise) -> String
    let isExerciseCompleted: (ExerciseLog) -> Bool
    let isExerciseActive: (ExerciseLog) -> Bool
    let supersetLetter: (ExerciseLog) -> String?
    /// Prescribed reps for strength rows, nil for cardio (the caller knows the modality).
    var repGoal: ((ExerciseLog) -> String?)? = nil
    /// Last working load or last cardio duration from a completed session, when known.
    var lastLoadCaption: ((ExerciseLog) -> String?)? = nil
    var onSelectExercise: ((Int) -> Void)? = nil
    var onAddExercise: (() -> Void)? = nil
    var onQuickSwap: ((Int) -> Void)? = nil
    var onToggleSuperset: ((Int) -> Void)? = nil
    var onMarkCompleted: ((Int) -> Void)? = nil
    var onRemoveExercise: ((Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            exercisePill(index: index, log: log)
                                .id(log.id)
                        }
                        if let onAddExercise {
                            Button(action: onAddExercise) {
                                Label("Add", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add exercise")
                            .accessibilityHint("Opens the exercise picker")
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: expandedExerciseIndex) { _, newIdx in
                    guard let idx = newIdx,
                          idx < logs.count else { return }
                    let targetId = logs[idx].id
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
            if activeExerciseIdsCount > 1 {
                Label(
                    "Superset: blue outlined exercises run back to back. Rest starts after the last letter.",
                    systemImage: "bolt.horizontal"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func exercisePill(index: Int, log: ExerciseLog) -> some View {
        let isSelected = expandedExerciseIndex == index
        let name = abbreviatedName(for: log.workoutExercise)
        let rec = log.workoutExercise.recommendedSets
        let done = log.workingSetCount
        let isPlaceholder = log.workoutExercise.isSlotPlaceholder
        let isCompleted = isExerciseCompleted(log)
        let inSuperset = isExerciseActive(log) && activeExerciseIdsCount > 1
        let letter = supersetLetter(log)
        let lastLoad = lastLoadCaption?(log)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedExerciseIndex = index
            }
            onSelectExercise?(index)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let letter {
                        Text(letter)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                            .frame(minWidth: 16)
                    }
                    Text(name)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    if isPlaceholder {
                        Image(systemName: "square.dashed")
                            .font(.caption2)
                    } else if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.green)
                    } else if rec > 0 {
                        Text("\(done)/\(rec)")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                    } else if done > 0 {
                        Text("\(done)")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                    }
                    if !isCompleted, rec > 0 || done > 0 {
                        pillProgressDots(done: done, target: max(rec, done), isSelected: isSelected)
                    }
                }
                if let lastLoad, !lastLoad.isEmpty {
                    Text(lastLoad)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                        .accessibilityIdentifier(FitLogA11yID.exercisePill.lastLoad)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillBackground(isSelected: isSelected, inSuperset: inSuperset))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(inSuperset && !isSelected ? Color.blue.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
            .opacity(isCompleted && !isSelected ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if log.workoutExercise.exerciseId != nil, let onQuickSwap {
                Button("Quick swap", systemImage: "arrow.left.arrow.right") { onQuickSwap(index) }
            }
            if log.workoutExercise.exerciseId != nil, let onToggleSuperset {
                Button(
                    inSuperset ? "Remove from superset round" : "Add to superset round",
                    systemImage: "bolt.horizontal"
                ) { onToggleSuperset(index) }
            }
            if log.workoutExercise.exerciseId != nil, !isCompleted, let onMarkCompleted {
                Button("Mark done", systemImage: "checkmark.circle") { onMarkCompleted(index) }
            }
            if let onRemoveExercise {
                Button("Remove", systemImage: "trash", role: .destructive) { onRemoveExercise(index) }
            }
        }
        .accessibilityLabel(
            WorkoutExercisePillAccessibility.pillLabel(
                name: name,
                done: done,
                rec: rec,
                isPlaceholder: isPlaceholder,
                letter: letter,
                repGoal: repGoal?(log),
                lastLoad: lastLoad
            )
        )
        .accessibilityHint(isSelected ? "Currently selected exercise" : "Double tap to log sets for this exercise")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func pillProgressDots(done: Int, target: Int, isSelected: Bool) -> some View {
        let n = min(6, max(1, target))
        return HStack(spacing: 2) {
            ForEach(0..<n, id: \.self) { i in
                Circle()
                    .fill(i < done ? (isSelected ? Color.white : Color.accentColor) : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func abbreviatedName(for we: WorkoutExercise) -> String {
        let full = displayName(we)
        if full.count <= 14 { return full }
        return String(full.prefix(12)) + "…"
    }

    private func pillBackground(isSelected: Bool, inSuperset: Bool) -> Color {
        if isSelected { return Color.accentColor }
        if inSuperset { return Color.blue.opacity(0.12) }
        return Color(.systemGray5)
    }
}

#Preview("Pills — last load") {
    struct PreviewHost: View {
        @State private var expanded: Int? = 0
        var body: some View {
            WorkoutExercisePillStrip(
                logs: [],
                expandedExerciseIndex: $expanded,
                activeExerciseIdsCount: 2,
                displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" },
                isExerciseCompleted: { _ in false },
                isExerciseActive: { _ in true },
                supersetLetter: { _ in "A" },
                lastLoadCaption: { _ in "Last 185 lb × 8 reps" },
                onAddExercise: {}
            )
        }
    }
    return PreviewHost()
}

#Preview("Pills — last load dark") {
    struct PreviewHost: View {
        @State private var expanded: Int? = 0
        var body: some View {
            WorkoutExercisePillStrip(
                logs: [],
                expandedExerciseIndex: $expanded,
                activeExerciseIdsCount: 1,
                displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" },
                isExerciseCompleted: { _ in false },
                isExerciseActive: { _ in false },
                supersetLetter: { _ in nil },
                lastLoadCaption: { _ in "Last 45:00" },
                onAddExercise: {}
            )
            .preferredColorScheme(.dark)
        }
    }
    return PreviewHost()
}
