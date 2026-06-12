//
//  HistoryFilterMenu.swift
//  FitLog
//

import SwiftUI

struct HistoryFilterMenu: View {
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        Menu {
            Picker("Time range", selection: $viewModel.dayRange) {
                ForEach(HistoryDayRange.allCases) { range in
                    Text(range.menuLabel).tag(range)
                }
            }
            Toggle("Compare to prior period", isOn: $viewModel.comparePriorPeriod)
                .disabled(viewModel.dayRange.priorWindow() == nil)
        } label: {
            Image(systemName: viewModel.hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : .primary)
        }
        .accessibilityLabel("History filters")
        .accessibilityHint("Change time range or compare to prior period")
    }
}
