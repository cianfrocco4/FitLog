//
//  PersonalRecordAnnouncementTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct PersonalRecordAnnouncementTests {

    @Test func message_joinsTitleAndDetail() {
        #expect(
            PersonalRecordAnnouncement.message(
                title: "New max weight",
                detail: "Bench Press 225 lb"
            ) == "New max weight. Bench Press 225 lb"
        )
    }

    @Test func message_handlesMissingParts() {
        #expect(PersonalRecordAnnouncement.message(title: "New PR", detail: "") == "New PR")
        #expect(PersonalRecordAnnouncement.message(title: "", detail: "225 lb") == "225 lb")
        #expect(PersonalRecordAnnouncement.message(title: "  ", detail: "  ") == "New personal record")
    }
}
