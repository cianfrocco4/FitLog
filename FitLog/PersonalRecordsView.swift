//
//  PersonalRecordsView.swift
//  FitLog
//

import SwiftUI

struct PersonalRecordsView: View {
    @EnvironmentObject var dataVM: DataManager

    private var records: [ArchivedPersonalRecord] {
        dataVM.allTimePersonalRecords()
    }

    var body: some View {
        List {
            if records.isEmpty {
                Section {
                    Text("Log workouts to build your PR timeline. Records include heaviest load, estimated 1RM, and set volume per exercise.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("Each entry is the first time you beat your previous best for that exercise and metric.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.exerciseName)
                                .font(.headline)
                            Spacer()
                            Text(row.kind.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text(valueLabel(row))
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(HistoryView.formatDateStatic(row.achievedAt))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Personal records")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func valueLabel(_ row: ArchivedPersonalRecord) -> String {
        let n = row.value
        let s = n == floor(n) ? "\(Int(n))" : String(format: "%.1f", n)
        switch row.kind {
        case .maxWeight, .estimatedOneRM:
            return "\(s) lb"
        case .maxVolumeSet:
            return "\(s) lb·rep"
        }
    }
}
