//
//  ProgramReviewSuggestion.swift
//  FitLog
//
//  Unified, optionally actionable suggestions for the Guided Coach review Checks section.
//

import Foundation

struct ProgramReviewSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let message: String
    let fixSummary: String?
    let action: SplitProposalProgramWarning.Suggestion?
    let blockIndex: Int?
    let severity: SplitProposalProgramWarning.Severity

    init(
        id: String,
        message: String,
        fixSummary: String?,
        action: SplitProposalProgramWarning.Suggestion?,
        blockIndex: Int?,
        severity: SplitProposalProgramWarning.Severity
    ) {
        self.id = id
        self.message = message
        self.fixSummary = fixSummary
        self.action = action
        self.blockIndex = blockIndex
        self.severity = severity
    }

    init(
        warning: SplitProposalProgramWarning,
        blockIndex: Int?,
        blockNamePrefix: String?
    ) {
        let prefix = blockNamePrefix?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message: String
        if let prefix, !prefix.isEmpty {
            message = "\(prefix): \(warning.message)"
        } else {
            message = warning.message
        }
        self.id = "\(blockIndex.map(String.init) ?? "all")|\(warning.id)"
        self.message = message
        self.fixSummary = Self.fixSummary(for: warning.suggestion)
        self.action = warning.suggestion
        self.blockIndex = blockIndex
        self.severity = warning.severity
    }

    static func fixSummary(for suggestion: SplitProposalProgramWarning.Suggestion?) -> String? {
        switch suggestion {
        case .openDay:
            return "Open the day to review and edit"
        case .addSlot(_, let label, _):
            return "Add a \(label) slot"
        case .regenerateWithNote:
            return "Regenerate with this note as a constraint"
        case .addDeloadPhase:
            return "Turn the last week into a 1-week deload (volume ×0.7)"
        case .raiseWeeklyVolume(let target):
            return "Raise weekly hard sets toward \(target)"
        case .none:
            return nil
        }
    }

    static func actionTitle(for suggestion: SplitProposalProgramWarning.Suggestion?) -> String? {
        switch suggestion {
        case .openDay:
            return "Open day"
        case .addSlot(_, let label, _):
            return "Add \(label)"
        case .regenerateWithNote:
            return "Regenerate with this note"
        case .addDeloadPhase:
            return "Add deload"
        case .raiseWeeklyVolume:
            return "Raise volume"
        case .none:
            return nil
        }
    }
}
