//
//  ReadinessWidget.swift
//  FitLogWidgets
//

import SwiftUI
import WidgetKit

private enum ReadinessWidgetDeepLink {
    static let quickLog = URL(string: "fitlog://quick-log")!
    static let openApp = URL(string: "fitlog://open")!
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
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: ReadinessWidgetEntry

    private var hasReadinessSnapshot: Bool {
        entry.score != nil || entry.bandTitle != nil || entry.summary != nil
    }

    /// Plan-only empty state is dense on small; keep the calendar line for medium+.
    private var showsEmptyStatePlanLine: Bool {
        widgetFamily != .systemSmall
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Readiness")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let score = entry.score {
                    Text("\(score)")
                        .font(.title2.weight(.bold).monospacedDigit())
                } else if hasReadinessSnapshot {
                    Text("—")
                        .font(.title2.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            if hasReadinessSnapshot {
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
            } else {
                Text("Open Workout Log AI")
                    .font(.caption.weight(.semibold))
                Text(emptyStateGuidance)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if showsEmptyStatePlanLine, let plan = entry.planTitle {
                    Label(plan, systemImage: "calendar")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Label(
                hasReadinessSnapshot ? "Quick log" : "Open app",
                systemImage: hasReadinessSnapshot ? "plus.circle.fill" : "arrow.up.forward.app"
            )
            .font(.caption2.weight(.semibold))
        }
        .widgetURL(hasReadinessSnapshot ? ReadinessWidgetDeepLink.quickLog : ReadinessWidgetDeepLink.openApp)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(readinessAccessibilityLabel)
        .accessibilityHint(
            hasReadinessSnapshot
                ? "Opens Workout Log AI to log a set or start a workout"
                : emptyStateAccessibilityHint
        )
    }

    /// Avoid asking users to refresh a plan that is already visible from the App Group payload.
    /// Wording stays soft: `fitlog://open` only lands on Home; readiness updates when the app becomes active.
    private var emptyStateGuidance: String {
        entry.planTitle == nil
            ? "Update readiness and today’s plan"
            : "Update readiness"
    }

    private var emptyStateAccessibilityHint: String {
        entry.planTitle == nil
            ? "Opens Workout Log AI to update readiness and today’s plan"
            : "Opens Workout Log AI to update readiness"
    }

    private var readinessAccessibilityLabel: String {
        guard hasReadinessSnapshot else {
            let updatePart = entry.planTitle == nil
                ? "Open Workout Log AI to update readiness and today’s plan"
                : "Open Workout Log AI to update readiness"
            var parts = ["Readiness unavailable", updatePart]
            if let plan = entry.planTitle {
                parts.append("Today's plan: \(plan)")
            }
            return parts.joined(separator: ", ")
        }

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
        .description("Today's readiness score, plan, and a shortcut into the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
