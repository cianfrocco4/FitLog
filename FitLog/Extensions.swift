//
//  Extensions.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/1/26.
//

import SwiftUI

//extension Array where Element == Workout {
//    subscript(id: UUID) -> Binding<Workout>? {
//        if let index = firstIndex(where: { $0.id == id }) {
//            return Binding(
//                get: { self[index] },
//                set: { newValue in
//                    self[index] = newValue
//                }
//            )
//        }
//        return nil
//    }
//}

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
