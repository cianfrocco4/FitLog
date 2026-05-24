//
//  ExercisesLibraryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

/// Wrapper so we can use `sheet(item:)` with an optional exercise and avoid blank sheet content.
private struct EditableExerciseItem: Identifiable {
    let exercise: Exercise
    var id: UUID { exercise.id }
}

private struct LocalRenameExerciseItem: Identifiable {
    let exercise: Exercise
    var id: UUID { exercise.id }
}

enum ExerciseLibraryFilter: String, CaseIterable {
    case all = "All"
    case custom = "Custom"
    case builtIn = "Built-in"
}

/// Top-level modality filter for Strength / Cardio / Hybrid / All.
enum ExerciseLibraryModalityFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
    case hybrid = "Hybrid"

    var id: String { rawValue }
}

enum ExerciseLibraryBrowseMode: String, CaseIterable {
    case flatAZ = "A–Z"
    case byCategory = "By category"
}

struct ExercisesLibraryView: View {
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject private var aiService: AIService
    @State private var showAddSheet = false
    @State private var exerciseToEdit: EditableExerciseItem?
    @State private var exerciseToRenameLocally: LocalRenameExerciseItem?
    @State private var searchText = ""
    @State private var libraryFilter: ExerciseLibraryFilter = .all
    @State private var modalityFilter: ExerciseLibraryModalityFilter = .all
    @State private var browseMode: ExerciseLibraryBrowseMode = .byCategory
    @State private var favoriteIds: Set<UUID> = []

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var scopedExercises: [Exercise] {
        var list = dataVM.globalExercises
        switch modalityFilter {
        case .all: break
        case .strength: list = list.filter { $0.modality == .strength }
        case .cardio: list = list.filter { $0.modality == .cardio }
        case .hybrid: list = list.filter { $0.modality == .hybrid }
        }
        switch libraryFilter {
        case .all: break
        case .custom: list = list.filter { $0.isCustom }
        case .builtIn: list = list.filter { !$0.isCustom }
        }
        return list
    }

    private var filteredExercises: [Exercise] {
        let q = searchQuery
        guard !q.isEmpty else { return scopedExercises }
        return scopedExercises.filter { ex in
            dataVM.resolvedDisplayName(for: ex).localizedCaseInsensitiveContains(q)
                || ex.name.localizedCaseInsensitiveContains(q)
                || (ex.targetedMuscles.first ?? .other).rawValue.localizedCaseInsensitiveContains(q)
                || ex.targetedMuscles.contains { $0.rawValue.localizedCaseInsensitiveContains(q) }
                || (ex.cardioMetadata?.activityKind.displayName.localizedCaseInsensitiveContains(q) ?? false)
                || (ex.cardioMetadata?.primaryMetric.displayName.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var flatSorted: [Exercise] {
        filteredExercises.sorted {
            dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
        }
    }

    private var useFlatList: Bool {
        !searchQuery.isEmpty || browseMode == .flatAZ
    }

    private var favoriteExercises: [Exercise] {
        scopedExercises.filter { favoriteIds.contains($0.id) }
            .sorted {
                dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }
    }

    /// Recents that are not already listed under Favorites (avoids duplicate row IDs in one List).
    private var recentExercises: [Exercise] {
        let recentIds = ExercisePickerPersistence.loadRecent()
        let byId = Dictionary(uniqueKeysWithValues: scopedExercises.map { ($0.id, $0) })
        return recentIds.compactMap { byId[$0] }.filter { !favoriteIds.contains($0.id) }
    }

    /// Exercises not shown in Favorites or Recent, so bucket rows never duplicate those IDs in the same List.
    private var exercisesForBucketGrouping: [Exercise] {
        let pinned = Set(favoriteExercises.map(\.id)).union(Set(recentExercises.map(\.id)))
        return scopedExercises.filter { !pinned.contains($0.id) }
    }

    private var bucketedSections: [(String, [(MuscleGroup, [Exercise])])] {
        ExerciseCategoryGrouping.bucketedSections(exercises: exercisesForBucketGrouping) { dataVM.resolvedDisplayName(for: $0) }
    }

    private var cardioActivitySections: [(CardioActivityKind, [Exercise])] {
        CardioExerciseCategoryGrouping.activitySections(exercises: exercisesForBucketGrouping) { dataVM.resolvedDisplayName(for: $0) }
    }

    private var categorySectionIds: [String] {
        var ids: [String] = []
        if !favoriteExercises.isEmpty { ids.append("favorites") }
        if !recentExercises.isEmpty { ids.append("recent") }
        if showCardioActivitySections {
            ids.append(contentsOf: cardioActivitySections.map { $0.0.rawValue })
        } else {
            ids.append(contentsOf: bucketedSections.map { $0.0.lowercased() })
        }
        return ids
    }

    private var showCardioActivitySections: Bool {
        browseMode == .byCategory && !useFlatList
            && (modalityFilter == .cardio || modalityFilter == .hybrid)
            && !cardioActivitySections.isEmpty
    }

    var body: some View {
        Group {
            if useFlatList {
                listFlat
            } else {
                listByCategory
            }
        }
        .navigationTitle("Exercise Library")
        .searchable(text: $searchText, prompt: "Search by name, muscle, or activity")
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Modality", selection: $modalityFilter) {
                ForEach(ExerciseLibraryModalityFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityLabel("Exercise modality filter")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Browse", selection: $browseMode) {
                        ForEach(ExerciseLibraryBrowseMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Picker("Show", selection: $libraryFilter) {
                        ForEach(ExerciseLibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("View", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add New") { showAddSheet = true }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NewExerciseSheet()
                .environment(dataVM)
                .environmentObject(aiService)
        }
        .sheet(item: $exerciseToRenameLocally) { item in
            LocalExerciseRenameSheet(
                exercise: item.exercise,
                initialDisplayName: dataVM.resolvedDisplayName(for: item.exercise)
            )
            .environment(dataVM)
        }
        .sheet(item: $exerciseToEdit, onDismiss: { exerciseToEdit = nil }) { item in
            EditExerciseSheet(exercise: item.exercise)
        }
        .onAppear {
            favoriteIds = ExercisePickerPersistence.loadFavorites()
        }
    }

    private var listFlat: some View {
        List {
            Section {
                ForEach(flatSorted) { ex in
                    libraryRow(ex)
                }
            }
        }
    }

    private var listByCategory: some View {
        ScrollViewReader { proxy in
            List {
                if !favoriteExercises.isEmpty {
                    Section(header: Text("Favorites")) {
                        ForEach(favoriteExercises) { ex in
                            libraryRow(ex)
                        }
                    }
                    .id("favorites")
                }
                if !recentExercises.isEmpty {
                    Section(header: Text("Recent")) {
                        ForEach(recentExercises) { ex in
                            libraryRow(ex)
                        }
                    }
                    .id("recent")
                }
                if showCardioActivitySections {
                    ForEach(cardioActivitySections, id: \.0) { activity, list in
                        Section {
                            ForEach(list) { ex in
                                libraryRow(ex)
                            }
                        } header: {
                            ExerciseLibraryActivityHeader(activity: activity)
                        }
                        .id(activity.rawValue)
                    }
                } else {
                    ForEach(bucketedSections, id: \.0) { bucket, musclePairs in
                        Section {
                            ForEach(musclePairs, id: \.0.id) { muscle, list in
                                Section {
                                    ForEach(list) { ex in
                                        libraryRow(ex)
                                    }
                                } header: {
                                    ExerciseLibraryMuscleGroupHeader(name: muscle.rawValue)
                                }
                            }
                        } header: {
                            ExerciseLibraryBucketSectionHeader(title: bucket)
                        }
                        .id(bucket.lowercased())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .fitlogWorkoutBarContentInset()
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if categorySectionIds.count > 1 {
                    ExerciseSectionIndexStrip(proxy: proxy, ids: categorySectionIds)
                }
            }
        }
    }

    @ViewBuilder
    private func libraryRow(_ ex: Exercise) -> some View {
        HStack(spacing: 0) {
            NavigationLink {
                ExerciseDetailView(exerciseId: ex.id)
            } label: {
                HStack(spacing: 8) {
                    Text(dataVM.resolvedDisplayName(for: ex))
                    Spacer(minLength: 8)
                    statusBadges(for: ex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                toggleFavorite(ex.id)
            } label: {
                Image(systemName: favoriteIds.contains(ex.id) ? "heart.fill" : "heart")
                    .foregroundStyle(favoriteIds.contains(ex.id) ? .red : .secondary)
                    .font(.body)
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .contextMenu {
            contextMenuButtons(for: ex)
        }
    }

    @ViewBuilder
    private func statusBadges(for ex: Exercise) -> some View {
        HStack(spacing: 6) {
            if ex.modality != .strength {
                Text(ex.modality.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(FitlogPalette.chartSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(FitlogPalette.chartSecondary.opacity(0.15), in: Capsule())
            }
            if let activity = ex.cardioMetadata?.activityKind, ex.modality != .strength {
                Text(activity.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            if dataVM.hasLocalDisplayName(for: ex.id) {
                Text("Renamed")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            if ex.isCustom {
                Text("Custom")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func contextMenuButtons(for ex: Exercise) -> some View {
        if !ex.isCustom {
            Button {
                exerciseToRenameLocally = LocalRenameExerciseItem(exercise: ex)
            } label: {
                Label("Rename locally", systemImage: "textformat")
            }
        }
        Button {
            exerciseToEdit = EditableExerciseItem(exercise: ex)
        } label: {
            Label(ex.isCustom ? "Edit" : "Configuration options", systemImage: "pencil")
        }
    }

    private func toggleFavorite(_ id: UUID) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        ExercisePickerPersistence.saveFavorites(favoriteIds)
    }
}

// MARK: - Section headers (visually distinct from exercise rows)

private struct ExerciseLibraryBucketSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ExerciseLibraryActivityHeader: View {
    let activity: CardioActivityKind

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: activity.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FitlogPalette.chartSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Activity")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(activity.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FitlogPalette.chartSecondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Activity, \(activity.displayName)")
    }
}

private struct ExerciseLibraryMuscleGroupHeader: View {
    let name: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Muscle group")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Muscle group, \(name)")
    }
}
