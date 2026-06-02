//
//  PersistenceFailureReporter.swift
//  FitLog
//
//  Surfaces SwiftData save failures to the UI.
//

import Foundation
import Observation

@Observable
@MainActor
final class PersistenceFailureReporter {
    var alertMessage: String?

    func report(_ message: String) {
        alertMessage = message
    }

    func clear() {
        alertMessage = nil
    }
}
