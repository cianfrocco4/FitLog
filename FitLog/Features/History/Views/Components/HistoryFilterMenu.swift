//
//  HistoryFilterMenu.swift
//  FitLog
//

import SwiftUI

struct HistoryFilterMenu: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Bindable var viewModel: HistoryViewModel
    @State private var showPaywall = false
    @State private var paywallTrigger: PremiumFeature = .unlimitedHistory

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
        .accessibilityLabel("History filters")
        .accessibilityHint("Change time range or compare to prior period. Sessions older than the range stay listed.")
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                triggerFeature: paywallTrigger,
                analyticsSource: "history_filter"
            )
            .environment(entitlementStore)
        }
    }
}
