//
//  PersonalRecordAnnouncement.swift
//  FitLog
//
//  VoiceOver copy when a personal-record celebration appears.
//

import Foundation

enum PersonalRecordAnnouncement {
    static func message(title: String, detail: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return trimmedDetail.isEmpty ? "New personal record" : trimmedDetail
        }
        if trimmedDetail.isEmpty {
            return trimmedTitle
        }
        return "\(trimmedTitle). \(trimmedDetail)"
    }
}
