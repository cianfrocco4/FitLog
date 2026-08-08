//
//  HistoryFilterMenu.swift
//  FitLog
//

import SwiftUI

struct HistoryFilterMenu: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Bindable var viewModel: HistoryViewModel
    @State private var showPaywall = false

    /// Rejects Premium-only ranges for free users without briefly mutating `dayRange` (avoids KPI flash).
    private var dayRangeSelection: Binding<HistoryDayRange> {
        PremiumGatedSelection.binding(
            get: { viewModel.dayRange },
            set: { viewModel.dayRange = $0 },
            requiresPremium: { $0.requiresPremium },
            hasPremiumAccess: { entitlementStore.hasAccess(to: .unlimitedHistory) },
            onDenied: { showPaywall = true }
        )
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
            Toggle("Compare to prior period", isOn: $viewModel.comparePriorPeriod)
                .disabled(viewModel.dayRange.priorWindow() == nil || !entitlementStore.hasAccess(to: .advancedAnalytics))
        } label: {
            Image(systemName: viewModel.hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : .primary)
        }
        .accessibilityLabel("History filters")
        .accessibilityHint("Change time range or compare to prior period")
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .unlimitedHistory)
                .environment(entitlementStore)
        }
    }
}
