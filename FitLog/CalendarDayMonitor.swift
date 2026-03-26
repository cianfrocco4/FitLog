//
//  CalendarDayMonitor.swift
//  FitLog
//
//  Lightweight observable that only publishes when the local calendar day
//  actually changes, replacing the blunt calendarDayRefresh counter that
//  fired on every scene-phase transition.
//

import Foundation
import Combine
import UIKit

final class CalendarDayMonitor: ObservableObject {
    @Published private(set) var currentDayKey: String

    private var cancellables = Set<AnyCancellable>()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.currentDayKey = TrainingProgramState.dayKey(for: Date(), calendar: calendar)

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIScene.didActivateNotification))
            .sink { [weak self] _ in
                self?.checkForDayChange()
            }
            .store(in: &cancellables)
    }

    private func checkForDayChange() {
        let newKey = TrainingProgramState.dayKey(for: Date(), calendar: calendar)
        if newKey != currentDayKey {
            currentDayKey = newKey
        }
    }
}
