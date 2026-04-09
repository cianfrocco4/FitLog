//
//  TodayPlanWidget.swift
//  FitLog (Widget Extension — add manually)
//
//  In Xcode: File → New → Target → Widget Extension, name it FitLogWidget,
//  add this file to that target, enable the App Group `group.com.acianfrocco.FitLog`
//  on both the app and widget targets, then build.
//

import WidgetKit
import SwiftUI

private let appGroupId = "group.com.acianfrocco.FitLog"
private let snapshotKey = "fitlog.widget.todayPlan.v1"

private struct Snapshot: Codable {
    var title: String
    var subtitle: String
    var isRest: Bool
    var hasLoggedWorkout: Bool
    var updatedAt: Date
}

struct TodayPlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayPlanEntry {
        TodayPlanEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayPlanEntry) -> Void) {
        completion(TodayPlanEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayPlanEntry>) -> Void) {
        let entry = TodayPlanEntry(date: Date(), snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

struct TodayPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct TodayPlanWidgetEntryView: View {
    var entry: TodayPlanProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let s = entry.snapshot {
                Text(s.title)
                    .font(.headline.weight(.semibold))
                    .minimumScaleFactor(0.8)
                Text(s.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Open FitLog")
                    .font(.headline)
                Text("Plan data will appear here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

/// Add `TodayPlanWidget()` to the `@main` WidgetBundle Xcode generates for the extension.
struct TodayPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.acianfrocco.FitLog.todayplan", provider: TodayPlanProvider()) { entry in
            TodayPlanWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today’s plan")
        .description("Shows today’s scheduled workout from FitLog.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
