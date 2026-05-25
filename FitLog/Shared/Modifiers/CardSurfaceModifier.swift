//
//  CardSurfaceModifier.swift
//  FitLog
//
//  Consistent card styling for elevated content (Task 28).
//

import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FitlogPalette.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
