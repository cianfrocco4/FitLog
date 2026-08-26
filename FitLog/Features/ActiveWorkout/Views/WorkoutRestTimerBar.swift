//
//  WorkoutRestTimerBar.swift
//  FitLog
//
//  Gym-optimized rest countdown: ring progress, large digits, ±15, skip, swipe to adjust.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WorkoutRestTimerBar: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    var nextUpSubtitle: String = WorkoutRestTimerBarCopy.subtitle(for: .unknown)
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    @State private var swipeAdjustTrigger = 0
    @State private var buttonAdjustTrigger = 0

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(remainingSeconds) / CGFloat(totalSeconds)
    }

    private var ringColor: Color {
        if remainingSeconds <= 10 { return .red }
        if remainingSeconds <= 30 { return FitlogPalette.caution }
        return FitlogPalette.success
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.35), value: progress)
                Text("\(remainingSeconds)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(width: 52, height: 52)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rest timer, \(nextUpSubtitle)")
            .accessibilityValue("\(remainingSeconds) seconds remaining")
            .accessibilityHint("Swipe left or right to add or subtract 15 seconds")

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(nextUpSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    onAdjust(-15)
                    buttonAdjustTrigger += 1
                } label: {
                    Text("−15")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(FitlogPalette.caution)
                .accessibilityLabel("Subtract 15 seconds from rest")
                .accessibilityHint("Reduces the rest countdown")

                Button {
                    onAdjust(15)
                    buttonAdjustTrigger += 1
                } label: {
                    Text("+15")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(FitlogPalette.caution)
                .accessibilityLabel("Add 15 seconds to rest")
                .accessibilityHint("Increases the rest countdown")

                Button {
                    // Skip sets remaining rest to 0 and unmounts this bar in the same
                    // update, so `.sensoryFeedback` on a local trigger never plays.
                    playSkipRestHaptic()
                    onSkip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 56, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Skip rest")
                .accessibilityHint("Ends the rest timer immediately")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    if value.translation.width > 40 {
                        onAdjust(15)
                        swipeAdjustTrigger += 1
                    } else if value.translation.width < -40 {
                        onAdjust(-15)
                        swipeAdjustTrigger += 1
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: buttonAdjustTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: swipeAdjustTrigger)
    }

    private func playSkipRestHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview("Rest active") {
    WorkoutRestTimerBar(
        remainingSeconds: 45,
        totalSeconds: 90,
        nextUpSubtitle: WorkoutRestTimerBarCopy.subtitle(for: .sameExercise(name: "Bench Press")),
        onAdjust: { _ in },
        onSkip: {}
    )
    .padding()
}

#Preview("Up next exercise") {
    WorkoutRestTimerBar(
        remainingSeconds: 60,
        totalSeconds: 90,
        nextUpSubtitle: WorkoutRestTimerBarCopy.subtitle(for: .nextExercise(name: "Barbell Row")),
        onAdjust: { _ in },
        onSkip: {}
    )
    .padding()
}

#Preview("Low time") {
    WorkoutRestTimerBar(
        remainingSeconds: 8,
        totalSeconds: 90,
        nextUpSubtitle: WorkoutRestTimerBarCopy.subtitle(for: .readyToFinish),
        onAdjust: { _ in },
        onSkip: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
