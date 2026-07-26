//
//  ReadinessCardView.swift
//  FitLog
//

import SwiftUI

struct ReadinessCardView: View {
    let score: ReadinessScore?
    let isLoading: Bool
    var healthConnectState: ReadinessHealthConnectState = .hidden
    /// Free-user soft CTA; tap opens Premium (no auto sheet).
    var showPremiumTrendsCTA: Bool = false
    var onTap: () -> Void
    var onConnectHealth: (() -> Void)?
    var onUnlockTrends: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    readinessRing
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Readiness")
                            .font(.headline)
                        if isLoading {
                            Text("Updating readiness…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let score {
                            Text(score.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text("Training load only until Apple Health is connected.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(readinessAccessibilityLabel)
            .accessibilityHint("Opens readiness details and how your score is calculated")

            switch healthConnectState {
            case .hidden:
                EmptyView()
            case .connect:
                if let onConnectHealth {
                    Button(action: onConnectHealth) {
                        Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Requests permission to read sleep, heart rate, and HRV from Apple Health")
                }
            case .noData:
                Label {
                    Text("No Apple Health recovery data found yet. Sleep, HRV, or resting heart rate from Apple Watch or other sources will improve this score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("No Apple Health recovery data found yet")
            }

            if showPremiumTrendsCTA, score != nil, let onUnlockTrends {
                Button(action: onUnlockTrends) {
                    Label("Trends unlock with Premium", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Shows Premium options for readiness trends")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var readinessRing: some View {
        let value = score?.score ?? 0
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 100)) / 100)
                .stroke(readinessColor(for: value), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private var readinessAccessibilityLabel: String {
        if let score {
            return "Readiness score \(score.score) out of 100. \(score.band.displayTitle)."
        }
        return "Readiness score unavailable"
    }

    private func readinessColor(for score: Int) -> Color {
        switch score {
        case ..<45: return .orange
        case 45..<65: return .yellow
        case 65..<80: return .mint
        default: return .green
        }
    }
}

#Preview("Connect") {
    ReadinessCardView(
        score: ReadinessScore(
            id: UUID(),
            dayKey: "2026-06-28",
            computedAt: Date(),
            score: 72,
            band: .good,
            summary: "Good readiness (72/100). You're recovered enough for a solid training day.",
            components: []
        ),
        isLoading: false,
        healthConnectState: .connect,
        onTap: {},
        onConnectHealth: {}
    )
    .padding()
}

#Preview("No data") {
    ReadinessCardView(
        score: ReadinessScore(
            id: UUID(),
            dayKey: "2026-06-28",
            computedAt: Date(),
            score: 58,
            band: .moderate,
            summary: "Moderate readiness based on training load.",
            components: []
        ),
        isLoading: false,
        healthConnectState: .noData,
        onTap: {},
        onConnectHealth: nil
    )
    .padding()
}
