//
//  Extensions.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/1/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers


extension View {
    /// Keyboard accessory with a trailing Done button; use on every screen that shows text fields.
    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Binding where Value == [Workout] {
    subscript(id: UUID) -> Binding<Workout>? {
        // Find the index in the current value of the binding
        guard let index = wrappedValue.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        
        // Return a new Binding that points into the original array binding
        return Binding<Workout>(
            get: { self.wrappedValue[index] },
            set: { self.wrappedValue[index] = $0 }
        )
    }
}

extension UTType {
    static let fitlogArchive = UTType(exportedAs: "com.acianfrocco.fitlog.archive", conformingTo: .json)
    static let fitlogCSV = UTType(exportedAs: "com.acianfrocco.fitlog.csv", conformingTo: .commaSeparatedText)
}
