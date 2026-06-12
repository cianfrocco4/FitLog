//
//  CoachContextSheet.swift
//  FitLog
//
//  Shows what data the Coach can see.
//

import SwiftUI

struct CoachContextSheet: View {
    let summary: CoachContextSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Today's plan") {
                    Text(summary.todayPlan)
                }
                Section("Training program") {
                    Text(summary.programSummary)
                }
                Section("Workout library") {
                    LabeledContent("Templates", value: "\(summary.workoutCount)")
                }
                Section("Recent training") {
                    LabeledContent("Sessions in snapshot", value: "\(summary.recentSessionCount)")
                    LabeledContent("Completed last 7 days", value: "\(summary.sessionsThisWeek)")
                }
                if summary.wasTruncated {
                    Section {
                        Label("Some details were shortened to fit the coach context limit.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("The coach only uses this \(AppBrand.name) data. It does not browse the web or access data outside your app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("What your coach sees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
