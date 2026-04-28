//
//  RestTimerLiveActivityWidget.swift
//  FitLogLiveActivityExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.workoutName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(context.state.headline)
                    .font(.subheadline.weight(.medium))
                Text(restTimerFormatted(context.state.remainingSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Rest")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(restTimerFormatted(context.state.remainingSeconds))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text("\(max(0, context.state.remainingSeconds))")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

private func restTimerFormatted(_ sec: Int) -> String {
    let s = max(0, sec)
    let m = s / 60
    let r = s % 60
    return String(format: "%d:%02d", m, r)
}

@main
struct FitLogLiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivityWidget()
    }
}
