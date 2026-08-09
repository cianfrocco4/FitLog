//
//  CoachProgramGenerationProgressView.swift
//  FitLog
//
//  Prominent loading state while the guided coach builds a program.
//

import SwiftUI

struct CoachProgramGenerationProgressView: View {
    let statusMessage: String
    let stage: DynamicProgramBuilderViewModel.GenerationStage
    let blockCompleted: Int
    let blockTotal: Int
    let programTitle: String
    let daysPerWeek: Int

    @State private var pulsePhase = false

    private var showsBlockProgress: Bool {
        blockTotal > 1
    }

    private var blockProgressFraction: Double {
        guard blockTotal > 0 else { return 0 }
        return Double(blockCompleted) / Double(blockTotal)
    }

    /// Step index for Connecting / Designing / Finalizing bubbles.
    private var activeStepIndex: Int {
        switch stage {
        case .idle, .connecting:
            return 0
        case .designing:
            return 1
        case .finalizing, .ready:
            return 2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statusSection
            if showsBlockProgress {
                blockProgressSection
            }
            stepTimeline
            previewSkeleton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FitlogPalette.subtleFill.opacity(0.65))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(FitlogPalette.chartPrimary.opacity(pulsePhase ? 0.45 : 0.2), lineWidth: 1.5)
        }
        // `.contain` keeps each step readable so VoiceOver can convey stage progress.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(headerTitle)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FitlogPalette.chartPrimary.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .symbolEffect(.pulse, options: .repeating)
                    .foregroundStyle(FitlogPalette.chartPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                Text(programTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusSection: some View {
        HStack(spacing: 12) {
            if stage != .ready {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FitlogPalette.success)
            }
            Text(statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: statusMessage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusMessage)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var blockProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Program phases")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(blockCompleted) of \(blockTotal)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: blockProgressFraction)
                .tint(FitlogPalette.chartPrimary)
                .animation(.easeInOut(duration: 0.35), value: blockCompleted)
        }
    }

    private var stepTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            generationStep(
                title: "Connecting",
                detail: "Checking AI service",
                index: 0
            )
            generationStep(
                title: "Designing workouts",
                detail: daysPerWeekLabel,
                index: 1
            )
            generationStep(
                title: stage == .ready ? "Ready" : "Finalizing",
                detail: stage == .ready ? "Opening your review" : "Preparing your review",
                index: 2
            )
        }
    }

    private var previewSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview loading")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<min(daysPerWeek, 4), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .fitlogShimmering()
                }
            }
            if daysPerWeek > 4 {
                FitlogSkeletonLine(widthFraction: 0.55, height: 12)
            }
        }
    }

    private func generationStep(title: String, detail: String, index: Int) -> some View {
        let isActive = activeStepIndex == index && stage != .ready
        let isComplete = activeStepIndex > index || stage == .ready

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(isActive || isComplete ? FitlogPalette.chartPrimary : Color.secondary.opacity(0.25), lineWidth: 2)
                    .frame(width: 24, height: 24)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FitlogPalette.success)
                } else if isActive {
                    Circle()
                        .fill(FitlogPalette.chartPrimary)
                        .frame(width: 10, height: 10)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive || isComplete ? .primary : .secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(detail)\(isComplete ? ", complete" : isActive ? ", in progress" : ", pending")")
    }

    private var daysPerWeekLabel: String {
        "\(daysPerWeek) training day\(daysPerWeek == 1 ? "" : "s") per week"
    }

    private var headerTitle: String {
        stage == .ready ? "Program ready" : "Building your program"
    }
}

#Preview("Connecting") {
    ScrollView {
        CoachProgramGenerationProgressView(
            statusMessage: "Connecting to AI…",
            stage: .connecting,
            blockCompleted: 0,
            blockTotal: 3,
            programTitle: "12-Week Strength Block",
            daysPerWeek: 4
        )
        .padding()
    }
}

#Preview("Generating phase 2 of 3") {
    ScrollView {
        CoachProgramGenerationProgressView(
            statusMessage: "Generating phase 2 of 3…",
            stage: .designing,
            blockCompleted: 2,
            blockTotal: 3,
            programTitle: "Hypertrophy Mesocycle",
            daysPerWeek: 5
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Ready") {
    ScrollView {
        CoachProgramGenerationProgressView(
            statusMessage: "Ready to review",
            stage: .ready,
            blockCompleted: 1,
            blockTotal: 1,
            programTitle: "Muscle Builder",
            daysPerWeek: 4
        )
        .padding()
    }
}
