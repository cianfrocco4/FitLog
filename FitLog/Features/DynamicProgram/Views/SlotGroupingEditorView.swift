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

    struct PartnerCandidate: Identifiable, Hashable {
        let id: UUID
        let label: String
    }

    private var workingKind: ExerciseGroupingKind {
        grouping?.kind ?? .standalone
    }

    var body: some View {
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
}
