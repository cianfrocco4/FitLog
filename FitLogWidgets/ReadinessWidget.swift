//
//  ReadinessWidget.swift
//  FitLogWidgets
//

import SwiftUI
import WidgetKit

private enum ReadinessWidgetDeepLink {
    static let quickLog = URL(string: "fitlog://quick-log")!
}

struct ReadinessWidgetEntry: TimelineEntry {
    let date: Date
    let score: Int?
    let bandTitle: String?
    let summary: String?
    let planTitle: String?
}

struct ReadinessWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessWidgetEntry {
        ReadinessWidgetEntry(date: Date(), score: 72, bandTitle: "Good", summary: "Good readiness", planTitle: "Upper body")
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> ReadinessWidgetEntry {
        let payload = WidgetSnapshotStore.read()
        return ReadinessWidgetEntry(
            date: payload?.updatedAt ?? Date(),
            score: payload?.readinessScore,
            bandTitle: payload?.readinessBandTitle,
            summary: payload?.readinessSummary,
            planTitle: payload?.todayPlanTitle
        )
    }
}

struct ReadinessWidgetView: View {
    let entry: ReadinessWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Readiness")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let score = entry.score {
                    Text("\(score)")
                        .font(.title2.weight(.bold).monospacedDigit())
                } else {
                    Text("—")
                        .font(.title2.weight(.bold))
                }
            }
            if let bandTitle = entry.bandTitle {
                Text(bandTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let plan = entry.planTitle {
                Label(plan, systemImage: "calendar")
                    .font(.caption2)
                    .lineLimit(1)
            }
            if let summary = entry.summary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Label("Quick log", systemImage: "plus.circle.fill")
                .font(.caption2.weight(.semibold))
        }
        .widgetURL(ReadinessWidgetDeepLink.quickLog)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .accessibilityLabel(readinessAccessibilityLabel)
        .accessibilityHint("Opens Workout Log AI to log a set or start a workout")
    }

    private var readinessAccessibilityLabel: String {
        var parts = ["Readiness"]
        if let score = entry.score {
            parts.append("\(score) out of 100")
        }
        if let bandTitle = entry.bandTitle {
            parts.append(bandTitle)
        }
        if let plan = entry.planTitle {
            parts.append("Today's plan: \(plan)")
        }
        return parts.joined(separator: ", ")
    }
}

struct ReadinessWidget: Widget {
    let kind = "ReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessWidgetProvider()) { entry in
            ReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Today's readiness score, plan, and quick-log shortcut.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
