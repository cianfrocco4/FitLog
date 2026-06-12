//
//  CoachChatParsingTests.swift
//  FitLogTests
//
//  SSE delta parsing and structured coach response parsing.
//

import Testing
@testable import FitLog

struct CoachChatParsingTests {

    @Test func parseSSEDataLine_extractsDeltaContent() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        let delta = AIService.parseSSEDataLine(line)
        #expect(delta == "Hello")
    }

    @Test func parseSSEDataLine_ignoresDoneMarker() {
        let line = "data: [DONE]"
        #expect(AIService.parseSSEDataLine(line) == nil)
    }

    @Test func parseStructuredCoachResponse_extractsReplyAndActions() {
        let raw = """
        Here is my advice.

        ```json
        {
          "reply": "Try Upper/Lower with 4 days.",
          "actions": [
            { "kind": "openProgramBuilder", "title": "Open program builder", "detail": "Build a new split", "prefill": "Upper/Lower 4x" }
          ]
        }
        ```
        """
        let parsed = AIService.parseStructuredCoachResponse(raw)
        #expect(parsed.reply == "Try Upper/Lower with 4 days.")
        #expect(parsed.actions.count == 1)
        #expect(parsed.actions.first?.kind == .openProgramBuilder)
        #expect(parsed.actions.first?.prefill == "Upper/Lower 4x")
    }

    @Test func parseStructuredCoachResponse_plainTextFallback() {
        let raw = "Just keep training consistently."
        let parsed = AIService.parseStructuredCoachResponse(raw)
        #expect(parsed.reply == "Just keep training consistently.")
        #expect(parsed.actions.isEmpty)
    }

    @Test func parseSSEDataLines_multipleDeltasInOrder() {
        let lines = [
            #"data: {"choices":[{"delta":{"content":"Hel"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"lo"}}]}"#,
            "data: [DONE]",
        ]
        let deltas = AIService.parseSSEDataLines(lines)
        #expect(deltas == ["Hel", "lo"])
    }

    @Test func stripPartialCoachJSONFenceForDisplay_hidesIncompleteFence() {
        let raw = "Good advice here.\n\n```json\n{\"reply\":"
        let stripped = AIService.stripPartialCoachJSONFenceForDisplay(raw)
        #expect(stripped == "Good advice here.")
    }

    @Test func stripPartialCoachJSONFenceForDisplay_hidesCompleteFence() {
        let raw = """
        Good advice.

        ```json
        {"reply": "Done", "actions": []}
        ```
        """
        let stripped = AIService.stripPartialCoachJSONFenceForDisplay(raw)
        #expect(stripped == "Good advice.")
    }
}
