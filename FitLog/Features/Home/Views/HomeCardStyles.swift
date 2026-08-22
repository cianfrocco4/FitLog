//
//  HomeCardStyles.swift
//  FitLog
//
//  Tiered card surfaces for the Home dashboard visual hierarchy.
//

import SwiftUI

enum HomeCardTier {
    case primary
    case secondary
    case tertiary
}

private struct HomeCardTierModifier: ViewModifier {
    let tier: HomeCardTier

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(overlay)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var background: some View {
        switch tier {
        case .primary:
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.14),
                            Color.accentColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .secondary:
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        case .tertiary:
            RoundedRectangle(cornerRadius: 16)
                .fill(FitlogPalette.subtleFill.opacity(0.55))
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch tier {
        case .primary:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5)
        case .secondary:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        case .tertiary:
            EmptyView()
        }
    }
}

extension View {
    func homeCardTier(_ tier: HomeCardTier) -> some View {
        modifier(HomeCardTierModifier(tier: tier))
    }
}

extension WorkoutKind {
    var homeSystemImage: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .hybrid: return "figure.strengthtraining.functional"
        }
    }

    var homeAccentColor: Color {
        switch self {
        case .strength: return FitlogPalette.chartPrimary
        case .cardio: return FitlogPalette.chartSecondary
        case .hybrid: return FitlogPalette.highlight
        }
    }
}

enum HomeWorkoutFormatting {
    static func estimatedDurationMinutes(exerciseCount: Int) -> Int {
        guard exerciseCount > 0 else { return 0 }
        return max(15, exerciseCount * 8)
    }

    static func lastDoneLabel(for date: Date?, reference: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "Never started" }
        let start = calendar.startOfDay(for: date)
        let ref = calendar.startOfDay(for: reference)
        let days = calendar.dateComponents([.day], from: start, to: ref).day ?? 0
        switch days {
        case 0: return "Last done today"
        case 1: return "Last done yesterday"
        default: return "Last done \(days)d ago"
        }
    }

    /// Compact stored-pound weight for Home rows, e.g. "185 lb".
    static func compactWeightLabel(pounds: Double?, unit: WeightDisplayUnit) -> String? {
        guard let pounds, pounds > 0, pounds.isFinite else { return nil }
        let display = WeightStoreConversion.displayValue(storedPounds: pounds, unit: unit)
        return "\(WeightStoreConversion.formatDisplay(display)) \(unit.shortLabel)"
    }

    static func lastDoneWithWeightLabel(
        date: Date?,
        weightPounds: Double?,
        unit: WeightDisplayUnit,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let done = lastDoneLabel(for: date, reference: reference, calendar: calendar)
        if let weight = compactWeightLabel(pounds: weightPounds, unit: unit) {
            return "\(done) · \(weight)"
        }
        return done
    }
}
