//
//  ProgramBuilderEntryView.swift
//  FitLog
//
//  Three-path entry: Quick Start gallery, AI chat builder, or custom wizard.
//

import SwiftUI

enum ProgramBuilderRoute: Hashable {
    case quickStart
    case aiChat
    case customBuild
}

struct ProgramBuilderEntryView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @Environment(DataManager.self) private var dataManager

    @State private var highlightQuickStart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                pathCards
                if highlightQuickStart {
                    tipBanner
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Program builder")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ProgramBuilderRoute.self) { route in
            switch route {
            case .quickStart:
                ProgramTemplateGalleryView(viewModel: viewModel)
            case .aiChat:
                AIProgramChatBuilderView(viewModel: viewModel)
            case .customBuild:
                DynamicProgramBuilderView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.bootstrapFromContext(dataManager: dataManager)
            highlightQuickStart = viewModel.shouldPromoteQuickStart
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How do you want to build?")
                .font(.title2.weight(.semibold))
            Text("Pick a fast path or customize every detail. You can edit everything before saving to Plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var pathCards: some View {
        VStack(spacing: 14) {
            pathCard(
                route: .quickStart,
                title: "Quick Start",
                subtitle: "One-tap curated programs for common goals and splits.",
                systemImage: "sparkles",
                tint: FitlogPalette.highlight,
                recommended: highlightQuickStart
            )
            pathCard(
                route: .aiChat,
                title: "AI Builder",
                subtitle: "Describe your program in plain language and refine it in chat.",
                systemImage: "bubble.left.and.text.bubble.right.fill",
                tint: FitlogPalette.chartPrimary,
                recommended: false
            )
            pathCard(
                route: .customBuild,
                title: "Custom Build",
                subtitle: "Step through essentials, structure, and review with full control.",
                systemImage: "slider.horizontal.3",
                tint: FitlogPalette.chartSecondary,
                recommended: false
            )
        }
    }

    private func pathCard(
        route: ProgramBuilderRoute,
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        recommended: Bool
    ) -> some View {
        NavigationLink(value: route) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if recommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(FitlogPalette.highlight.opacity(0.18)))
                                .foregroundStyle(FitlogPalette.highlight)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FitlogPalette.subtleFill)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private var tipBanner: some View {
        Label("New here? Quick Start gets you a complete program in one tap.", systemImage: "lightbulb.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
            .accessibilityLabel("Tip. New here? Quick Start gets you a complete program in one tap.")
    }
}

#Preview {
    NavigationStack {
        ProgramBuilderEntryView(viewModel: DynamicProgramBuilderViewModel())
    }
}
