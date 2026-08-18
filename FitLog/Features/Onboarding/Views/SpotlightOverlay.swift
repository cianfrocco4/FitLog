//
//  SpotlightOverlay.swift
//  FitLog
//
//  Dimmed cutout tour that highlights real Home / tab chrome after onboarding.
//

import SwiftUI

enum SpotlightCoordinateSpace {
    static let name = "fitlogSpotlightRoot"
}

struct SpotlightAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [SpotlightTarget: CGRect] = [:]

    static func reduce(
        value: inout [SpotlightTarget: CGRect],
        nextValue: () -> [SpotlightTarget: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SpotlightAnchorModifier: ViewModifier {
    let target: SpotlightTarget

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightAnchorPreferenceKey.self,
                    value: [target: geo.frame(in: .named(SpotlightCoordinateSpace.name))]
                )
            }
        }
    }
}

extension View {
    func spotlightAnchor(_ target: SpotlightTarget) -> some View {
        modifier(SpotlightAnchorModifier(target: target))
    }
}

struct SpotlightOverlay: View {
    let controller: SpotlightTourController
    let anchors: [SpotlightTarget: CGRect]
    var onFinished: () -> Void

    @State private var missingSkipSerial = 0
    @AccessibilityFocusState private var tooltipFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let hole = resolvedHole(in: geo.size)
            ZStack(alignment: .top) {
                SpotlightCutoutShape(hole: hole)
                    .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if let step = controller.currentStep {
                    tooltip(for: step, hole: hole, canvas: geo.size)
                        .padding(.horizontal, 20)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityFocused($tooltipFocused)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: controller.currentIndex) { _, _ in
            scheduleSkipIfMissing()
            tooltipFocused = true
        }
        .onChange(of: anchors) { _, _ in
            scheduleSkipIfMissing()
        }
        .onAppear {
            scheduleSkipIfMissing()
            tooltipFocused = true
        }
    }

    private func resolvedHole(in canvas: CGSize) -> CGRect? {
        guard let step = controller.currentStep else { return nil }
        guard let raw = resolvedFrame(for: step.target) else { return nil }
        let padded = raw.insetBy(dx: -8, dy: -8)
        let canvasRect = CGRect(origin: .zero, size: canvas)
        return padded.intersection(canvasRect)
    }

    private func resolvedFrame(for target: SpotlightTarget) -> CGRect? {
        if let rect = anchors[target], rect.width > 8, rect.height > 8 {
            return rect
        }
        if let fallback = target.fallback {
            return resolvedFrame(for: fallback)
        }
        return nil
    }

    private func scheduleSkipIfMissing() {
        missingSkipSerial += 1
        let serial = missingSkipSerial
        let index = controller.currentIndex
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard serial == missingSkipSerial else { return }
            guard controller.isActive, controller.currentIndex == index else { return }
            if resolvedFrame(for: controller.currentStep?.target ?? .firstRunHero) == nil {
                controller.skipMissingCurrentStep()
            }
        }
    }

    @ViewBuilder
    private func tooltip(for step: SpotlightTourStep, hole: CGRect?, canvas: CGSize) -> some View {
        let placeBelow: Bool = {
            guard let hole else { return true }
            return hole.midY < canvas.height * 0.42
        }()

        VStack(spacing: 0) {
            if placeBelow {
                Spacer(minLength: hole.map { $0.maxY + 16 } ?? 120)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(step.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(step.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Skip") {
                        controller.skip()
                        onFinished()
                    }
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("spotlight.skip")
                    .accessibilityHint("Dismisses the first-run tour")

                    Spacer(minLength: 0)

                    Button(controller.isLastStep ? "Got it" : "Next") {
                        let finishing = controller.isLastStep
                        controller.advance()
                        if finishing { onFinished() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(controller.isLastStep ? "spotlight.gotIt" : "spotlight.next")
                    .accessibilityHint(
                        controller.isLastStep
                            ? "Finishes the first-run tour"
                            : "Shows the next tip"
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(step.title). \(step.body)")

            if !placeBelow {
                Spacer(minLength: 24)
            }
        }
        .padding(.top, placeBelow ? 0 : 56)
        .padding(.bottom, placeBelow ? 28 : 0)
    }
}

private struct SpotlightCutoutShape: Shape {
    var hole: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let hole, hole.width > 1, hole.height > 1 {
            path.addRoundedRect(
                in: hole,
                cornerSize: CGSize(width: 16, height: 16)
            )
        }
        return path
    }
}

#Preview("Spotlight tooltip") {
    let controller = SpotlightTourController()
    return ZStack {
        Color.gray.opacity(0.3)
        SpotlightOverlay(
            controller: controller,
            anchors: [
                .firstRunHero: CGRect(x: 20, y: 140, width: 320, height: 220)
            ],
            onFinished: {}
        )
    }
    .onAppear {
        controller.start(kind: .explore, alreadyCompleted: false, workoutInProgress: false)
    }
}
