//
//  ProgramBuilderEntryView.swift
//  FitLog
//
//  Three-path entry: Guided Coach, Templates, or Advanced Builder.
//

import SwiftUI

enum ProgramBuilderRoute: Hashable {
    case guidedCoach
    case quickStart
    case customBuild
}

struct ProgramBuilderEntryView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @Environment(DataManager.self) private var dataManager

    @State private var coachVM: CoachConversationViewModel
    @State private var highlightGuidedCoach = false

    init(viewModel: DynamicProgramBuilderViewModel) {
        self.viewModel = viewModel
        _coachVM = State(wrappedValue: CoachConversationViewModel(builderViewModel: viewModel))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                pathCards
                if highlightGuidedCoach {
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
            case .guidedCoach:
                CoachConversationView(coachVM: coachVM)
            case .quickStart:
                ProgramTemplateGalleryView(viewModel: viewModel)
            case .customBuild:
                DynamicProgramBuilderView(viewModel: viewModel, hidesBuilderModePicker: false)
            }
        }
        .onAppear {
            viewModel.bootstrapFromContext(dataManager: dataManager)
            let savedRoute = SplitBuilderPreferencesStore.load().programBuilderEntryRouteRaw
            highlightGuidedCoach = savedRoute == nil || savedRoute == ProgramBuilderEntryRoute.guidedCoach.rawValue
                || viewModel.shouldPromoteQuickStart == false
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How do you want to build?")
                .font(.title2.weight(.semibold))
            Text("Start with your coach for personalized recommendations, pick a template, or customize every detail.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var pathCards: some View {
        VStack(spacing: 14) {
            pathCard(
                route: .guidedCoach,
                title: "Guided Coach",
                subtitle: "Answer a few questions. Your coach recommends a program and you stay in control.",
                systemImage: "figure.strengthtraining.traditional",
                tint: FitlogPalette.chartPrimary,
                recommended: highlightGuidedCoach
            )
            pathCard(
                route: .quickStart,
                title: "Templates",
                subtitle: "One-tap curated programs for common goals and splits.",
                systemImage: "sparkles",
                tint: FitlogPalette.highlight,
                recommended: false
            )
            pathCard(
                route: .customBuild,
                title: "Advanced Builder",
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
        .simultaneousGesture(TapGesture().onEnded {
            persistEntryRoute(route)
        })
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private func persistEntryRoute(_ route: ProgramBuilderRoute) {
        var state = SplitBuilderPreferencesStore.load()
        switch route {
        case .guidedCoach:
            state.programBuilderEntryRouteRaw = ProgramBuilderEntryRoute.guidedCoach.rawValue
        case .quickStart:
            state.programBuilderEntryRouteRaw = ProgramBuilderEntryRoute.templates.rawValue
        case .customBuild:
            state.programBuilderEntryRouteRaw = ProgramBuilderEntryRoute.advancedBuilder.rawValue
        }
        SplitBuilderPreferencesStore.save(state)
    }

    private var tipBanner: some View {
        Label("New here? Guided Coach walks you through goals, schedule, and recommendations like a personal trainer.", systemImage: "lightbulb.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
            .accessibilityLabel("Tip. New here? Guided Coach walks you through goals, schedule, and recommendations like a personal trainer.")
    }
}

#Preview {
    NavigationStack {
        ProgramBuilderEntryView(viewModel: DynamicProgramBuilderViewModel())
    }
}
