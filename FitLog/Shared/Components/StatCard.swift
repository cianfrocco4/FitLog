//
//  StatCard.swift
//  FitLog
//
//  Reusable stat display card for consistency (Task 28).
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String?
    let accentColor: Color
    
    init(title: String, value: String, systemImage: String? = nil, accentColor: Color = .accentColor) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.accentColor = accentColor
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)
            }
            
            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(FitlogPalette.subtleFill)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview("Single Stat") {
    StatCard(title: "Total Sets", value: "42", systemImage: "dumbbell.fill")
        .padding()
}

#Preview("Multiple Stats") {
    HStack(spacing: 12) {
        StatCard(title: "Weekly", value: "30", systemImage: "calendar", accentColor: .blue)
        StatCard(title: "Personal Best", value: "225", systemImage: "trophy.fill", accentColor: FitlogPalette.highlight)
    }
    .padding()
}
