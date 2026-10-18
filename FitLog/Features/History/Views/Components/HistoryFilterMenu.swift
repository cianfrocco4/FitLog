//
//  HistoryFilterMenu.swift
//  FitLog
//

import SwiftUI

struct HistoryFilterMenu: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @Bindable var viewModel: HistoryViewModel
    @State private var showPaywall = false
    @State private var paywallTrigger: PremiumFeature = .unlimitedHistory
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    /// Rejects Premium-only ranges for free users without briefly mutating `dayRange` (avoids KPI flash).
    private var dayRangeSelection: Binding<HistoryDayRange> {
        PremiumGatedSelection.binding(
            get: { viewModel.dayRange },
            set: { viewModel.dayRange = $0 },
            requiresPremium: { $0.requiresPremium },
            hasPremiumAccess: { entitlementStore.hasAccess(to: .unlimitedHistory) },
            onDenied: {
                paywallTrigger = .unlimitedHistory
                showPaywall = true
            }
        )
    }

    /// Free users tapping Compare open the paywall instead of a silently disabled toggle.
    private var comparePriorPeriodSelection: Binding<Bool> {
        Binding(
            get: { viewModel.comparePriorPeriod },
            set: { newValue in
                guard newValue else {
                    viewModel.comparePriorPeriod = false
                    return
                }
                guard viewModel.dayRange.priorWindow() != nil else { return }
                guard entitlementStore.hasAccess(to: .advancedAnalytics) else {
                    paywallTrigger = .advancedAnalytics
                    showPaywall = true
                    return
                }
                viewModel.comparePriorPeriod = true
            }
        )
    }

    private var canComparePriorPeriod: Bool {
        viewModel.dayRange.priorWindow() != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Menu {
                Picker("Time range", selection: dayRangeSelection) {
                    ForEach(HistoryDayRange.allCases) { range in
                        if !range.requiresPremium || entitlementStore.hasAccess(to: .unlimitedHistory) {
                            Text(range.menuLabel).tag(range)
                        } else {
                            Label("\(range.menuLabel) (Premium)", systemImage: "lock.fill").tag(range)
                        }
                    }
                }
                if entitlementStore.hasAccess(to: .advancedAnalytics) {
                    Toggle("Compare to prior period", isOn: comparePriorPeriodSelection)
                        .disabled(!canComparePriorPeriod)
                } else {
                    Button {
                        guard canComparePriorPeriod else { return }
                        paywallTrigger = .advancedAnalytics
                        showPaywall = true
                    } label: {
                        Label("Compare to prior period (Premium)", systemImage: "lock.fill")
                    }
                    .disabled(!canComparePriorPeriod)
                }
            } label: {
                Image(systemName: viewModel.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : .primary)
            }
            .accessibilityLabel(filterAccessibilityLabel)
            .accessibilityHint("Change time range or compare to prior period")
            .accessibilityValue(resolvedLastLoadCaption ?? "")

            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier(FitLogA11yID.historyFilter.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                triggerFeature: paywallTrigger,
                analyticsSource: "history_filter"
            )
            .environment(entitlementStore)
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return CoralLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    private var filterAccessibilityLabel: String {
        if let lastLoad = resolvedLastLoadCaption {
            return "History filters. \(lastLoad)"
        }
        return "History filters"
    }
}

#Preview("Filter · last load") {
    NavigationStack {
        List {
            Text("History")
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HistoryFilterMenu(
                    viewModel: HistoryViewModel(),
                    lastLoadCaption: "Last 185 lb × 8 reps",
                    resolvesLastLoadFromEnvironment: false
                )
            }
        }
    }
    .environment(EntitlementStore())
    .environmentObject(UserPreferences())
}

#Preview("Filter · dark cardio") {
    NavigationStack {
        List {
            Text("History")
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HistoryFilterMenu(
                    viewModel: HistoryViewModel(),
                    lastLoadCaption: "Last 45:00",
                    resolvesLastLoadFromEnvironment: false
                )
            }
        }
    }
    .environment(EntitlementStore())
    .environmentObject(UserPreferences())
    .preferredColorScheme(.dark)
}
