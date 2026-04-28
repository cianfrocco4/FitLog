//
//  FitlogPalette.swift
//  FitLog
//
//  Named colors that track light/dark and read consistently on materials.
//

import SwiftUI
import UIKit

enum FitlogPalette {
    /// Success / logged / active workout accent (replaces ad-hoc `.green`).
    static var success: Color { Color(uiColor: .systemGreen) }

    /// Caution / paused / missed (replaces ad-hoc `.orange` where semantic).
    static var caution: Color { Color(uiColor: .systemOrange) }

    /// Primary analytics / trend lines (indigo family, adapted per appearance).
    static var chartPrimary: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(displayP3Red: 0.45, green: 0.48, blue: 0.98, alpha: 1)
            }
            return UIColor(displayP3Red: 0.22, green: 0.25, blue: 0.72, alpha: 1)
        })
    }

    /// Secondary series / volume bars (cyan / teal family).
    static var chartSecondary: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(displayP3Red: 0.35, green: 0.82, blue: 0.85, alpha: 1)
            }
            return UIColor(displayP3Red: 0.08, green: 0.55, blue: 0.62, alpha: 1)
        })
    }

    /// PR / highlight chips (warm accent).
    static var highlight: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(displayP3Red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
            }
            return UIColor(displayP3Red: 0.85, green: 0.55, blue: 0.12, alpha: 1)
        })
    }

    /// Card / chip fill on grouped content (subtle, not full material).
    static var subtleFill: Color { Color(uiColor: .secondarySystemFill) }
}
