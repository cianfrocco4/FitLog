//
//  PRCelebrationOverlay.swift
//  FitLog
//
//  Non-blocking animated overlay that fires when the user logs a personal record.
//  Auto-dismisses after 3.5 s; tappable to expand a "Compare to best" mini-sheet.
//

import SwiftUI

struct PRCelebrationOverlay: View {
    let event: PersonalRecordEvent
    let unit: WeightDisplayUnit
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var showDetail = false
    @State private var confettiTrigger = 0

    var body: some View {
        VStack {
            Spacer()
            if isVisible {
                prBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { isVisible = true }
            confettiTrigger += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                dismissOverlay()
            }
        }
        .sensoryFeedback(.success, trigger: confettiTrigger)
        .sheet(isPresented: $showDetail) {
            PRCompareSheet(event: event, unit: unit)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Banner

    private var prBanner: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.yellow.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, value: confettiTrigger)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel("\(event.title): \(event.detail). Double-tap to compare to previous best.")
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .topTrailing) {
            Button {
                dismissOverlay()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Dismiss PR notification")
        }
    }

    private func dismissOverlay() {
        withAnimation(.easeOut(duration: 0.25)) { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
    }
}

// MARK: - Compare detail sheet

private struct PRCompareSheet: View {
    let event: PersonalRecordEvent
    let unit: WeightDisplayUnit

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("New record", systemImage: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Spacer()
                        Text(formattedValue(event.newValue))
                            .fontWeight(.bold)
                    }
                    if let prev = event.previousValue {
                        HStack {
                            Label("Previous best", systemImage: "clock")
                                .foregroundStyle(.secondary)
                            Spacer()
                            let delta = event.newValue - prev
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formattedValue(prev))
                                Text("+\(formattedValue(delta))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "rosette")
                            .foregroundStyle(.tint)
                        Text(event.exerciseName)
                    }
                }

                Section {
                    Label(event.kind.rawValue, systemImage: kindSymbol)
                } header: {
                    Text("Record type")
                }
            }
            .navigationTitle("New PR 🏆")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedValue(_ v: Double) -> String {
        switch event.kind {
        case .maxWeight, .estimatedOneRM:
            let d = WeightStoreConversion.displayValue(storedPounds: v, unit: unit)
            return "\(WeightStoreConversion.formatDisplay(d)) \(unit.shortLabel)"
        case .maxVolumeSet:
            return WeightStoreConversion.formatVolumeLbRep(v, unit: unit)
        }
    }

    private var kindSymbol: String {
        switch event.kind {
        case .maxWeight:     return "scalemass.fill"
        case .estimatedOneRM: return "chart.line.uptrend.xyaxis"
        case .maxVolumeSet:  return "flame.fill"
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        PRCelebrationOverlay(
            event: PersonalRecordEvent(
                exerciseId: UUID(), exerciseName: "Bench Press",
                kind: .maxWeight, newValue: 225, previousValue: 205
            ),
            unit: .pounds,
            onDismiss: {}
        )
    }
}

#Preview("Dark — 1RM") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        PRCelebrationOverlay(
            event: PersonalRecordEvent(
                exerciseId: UUID(), exerciseName: "Squat",
                kind: .estimatedOneRM, newValue: 300, previousValue: 285
            ),
            unit: .pounds,
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}
