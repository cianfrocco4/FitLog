//
//  CardSurfaceModifier.swift
//  FitLog
//
//  Consistent card styling for elevated content (Task 28).
//

import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FitlogPalette.subtleFill)
            .cornerRadius(cornerRadius)
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
