//
//  SlotGroupingEditorView.swift
//  FitLog
//
//  Link slots into supersets, circuits, etc. within one template day.
//

import SwiftUI

struct SlotGroupingEditorView: View {
    @Binding var grouping: ExerciseGrouping?
    let currentSlotId: UUID
    let partnerCandidates: [PartnerCandidate]
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    struct PartnerCandidate: Identifiable, Hashable {
        let id: UUID
        let label: String
    }

    private var workingKind: ExerciseGroupingKind {
        grouping?.kind ?? .standalone
    }

    var body: some View {
        if let lastLoad = resolvedLastLoadCaption {
            Text(lastLoad)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(FitLogA11yID.slotGrouping.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last working set or last cardio duration from a completed session")
                .accessibilityAddTraits(.isStaticText)
        }

        Picker("Grouping", selection: Binding(
            get: { workingKind },
            set: { newKind in
                if newKind == .standalone {
                    grouping = nil
                } else {
                    let existing = grouping?.partnerSlotIds ?? []
                    grouping = ExerciseGrouping(kind: newKind, partnerSlotIds: existing)
                }
            }
        )) {
            Text("Standalone").tag(ExerciseGroupingKind.standalone)
            Text("Superset").tag(ExerciseGroupingKind.superset)
            Text("Triset").tag(ExerciseGroupingKind.triset)
            Text("Circuit").tag(ExerciseGroupingKind.circuit)
            Text("Giant set").tag(ExerciseGroupingKind.giantSet)
        }
        .accessibilityHint("Links this slot with others performed back to back.")

        if workingKind != .standalone {
            ForEach(partnerCandidates) { cand in
                if cand.id != currentSlotId {
                    Toggle(isOn: Binding(
                        get: { (grouping?.partnerSlotIds ?? []).contains(cand.id) },
                        set: { on in
                            var g = grouping ?? ExerciseGrouping(kind: workingKind, partnerSlotIds: [])
                            var partners = Set(g.partnerSlotIds)
                            if on {
                                partners.insert(cand.id)
                            } else {
                                partners.remove(cand.id)
                            }
                            g.partnerSlotIds = Array(partners).sorted { $0.uuidString < $1.uuidString }
                            grouping = g
                        }
                    )) {
                        Text(cand.label)
                    }
                    .accessibilityLabel("Partner slot \(cand.label)")
                    .accessibilityHint("Include in this grouping.")
                }
            }

            Text(footer(for: workingKind))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func footer(for kind: ExerciseGroupingKind) -> String {
        switch kind {
        case .standalone: return ""
        case .superset: return "Pick one partner slot for a classic superset."
        case .triset: return "Pick two partner slots (three moves total including this one)."
        case .circuit, .giantSet: return "Pick every other slot in the circuit. Order follows the day list."
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return FernLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("Standalone") {
    struct Host: View {
        @State private var grouping: ExerciseGrouping?
        var body: some View {
            Form {
                SlotGroupingEditorView(
                    grouping: $grouping,
                    currentSlotId: UUID(),
                    partnerCandidates: [
                        .init(id: UUID(), label: "Bench Press"),
                        .init(id: UUID(), label: "Push-up")
                    ],
                    lastLoadCaption: "Last 185 lb × 8 reps",
                    resolvesLastLoadFromEnvironment: false
                )
            }
        }
    }
    return Host()
}

#Preview("Superset") {
    struct Host: View {
        let current = UUID()
        let partner = UUID()
        @State private var grouping: ExerciseGrouping? = ExerciseGrouping(
            kind: .superset,
            partnerSlotIds: []
        )
        var body: some View {
            Form {
                SlotGroupingEditorView(
                    grouping: $grouping,
                    currentSlotId: current,
                    partnerCandidates: [
                        .init(id: current, label: "Bench Press"),
                        .init(id: partner, label: "Push-up")
                    ],
                    lastLoadCaption: "Last 45:00",
                    resolvesLastLoadFromEnvironment: false
                )
            }
        }
    }
    return Host()
}
