//
//  ProgramTemplateGalleryView.swift
//  FitLog
//
//  Curated template grid with goal filters and one-tap generation.
//

import SwiftUI

struct ProgramTemplateGalleryView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(DataManager.self) private var dataManager
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var selectedCategory: ProgramTemplateGoalCategory?
    @State private var customizingTemplate: CuratedProgramTemplate?
    @State private var customWeeks = 8
    @State private var customSessions = 4
    @State private var navigateToReview = false
    @State private var showPaywall = false

    private var filteredTemplates: [CuratedProgramTemplate] {
        ProgramTemplateLibrary.templates(for: selectedCategory)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                categoryFilters
                templateGrid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Quick Start")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToReview) {
            DynamicProgramBuilderView(viewModel: viewModel)
        }
        .sheet(item: $customizingTemplate) { template in
            customizeSheet(template)
        }
        .overlay {
            if viewModel.isGenerating {
                generatingOverlay
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.generationSuccessCount)
        .alert(
            "Could not build program",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong while generating your program.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .aiProgramGeneration)
                .environment(entitlementStore)
        }
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ProgramTemplateGoalCategory.allCases) { category in
                    filterChip(title: category.title, selected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? Color.accentColor.opacity(0.16) : FitlogPalette.subtleFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var templateGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(filteredTemplates) { template in
                templateCard(template)
            }
        }
    }

    private func templateCard(_ template: CuratedProgramTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: template.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartPrimary)
                Spacer(minLength: 0)
                Text(template.difficulty)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }

            Text(template.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(template.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Label("\(template.sessionsPerWeek)× / week", systemImage: "calendar")
                Label("\(template.totalWeeks) weeks", systemImage: "clock")
                Label(template.splitLabel, systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Use") {
                    Task { await generate(from: template) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Use \(template.name)")

                Button("Customize") {
                    customWeeks = template.totalWeeks
                    customSessions = template.sessionsPerWeek
                    customizingTemplate = template
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Customize \(template.name) before generating")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .accessibilityElement(children: .contain)
    }

    private func customizeSheet(_ template: CuratedProgramTemplate) -> some View {
        NavigationStack {
            Form {
                Section("Overrides") {
                    Stepper("Sessions per week: \(customSessions)", value: $customSessions, in: 1 ... 7)
                    Stepper("Program length: \(customWeeks) weeks", value: $customWeeks, in: 4 ... 16)
                }
                Section {
                    Button {
                        customizingTemplate = nil
                        Task { await generate(from: template, weeks: customWeeks, sessions: customSessions) }
                    } label: {
                        Text("Generate program")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isGenerating)
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { customizingTemplate = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("Building your program…")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Building your program")
    }

    @MainActor
    private func generate(
        from template: CuratedProgramTemplate,
        weeks: Int? = nil,
        sessions: Int? = nil
    ) async {
        guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
            showPaywall = true
            return
        }
        viewModel.applyCuratedTemplate(
            template,
            overrideWeeks: weeks,
            overrideSessions: sessions
        )
        await viewModel.generate(aiService: aiService, dataManager: dataManager, entitlementStore: entitlementStore)
        if viewModel.generatedProgram != nil {
            navigateToReview = true
        }
    }
}

extension CuratedProgramTemplate: Hashable {
    static func == (lhs: CuratedProgramTemplate, rhs: CuratedProgramTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
