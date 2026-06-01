//
//  CoachInlineDiscussThread.swift
//  FitLog
//
//  Inline per-card discuss thread for Guided Coach recommendations.
//

import SwiftUI

struct CoachInlineDiscussThread: View {
    let topic: CoachRecommendationTopic
    let thread: CoachDiscussThread
    @Binding var draftText: String
    let isActive: Bool
    let shouldFocusComposer: Bool
    let onSend: () -> Void
    let onApplySuggestion: (CoachFollowUpSuggestedChange) -> Void
    let onDone: () -> Void
    let onReopenDiscuss: () -> Void

    @FocusState private var isComposerFocused: Bool
    @State private var showsEarlierMessages = false

    private let collapseThreshold = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 1)
                Text("Discussion")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 1)
            }

            let visible = thread.visibleMessages
            let hiddenCount = max(0, visible.count - collapseThreshold)

            if isActive {
                if hiddenCount > 0, !showsEarlierMessages {
                    Button("Show earlier discussion (\(hiddenCount) messages)") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showsEarlierMessages = true
                        }
                    }
                    .font(.caption)
                    .accessibilityHint("Reveal earlier messages in this discussion")
                }

                let displayed = showsEarlierMessages || hiddenCount == 0
                    ? visible
                    : Array(visible.suffix(collapseThreshold))

                ForEach(displayed) { message in
                    messageView(message)
                        .id(message.id)
                }
            }

            if isActive {
                activeComposer
            } else if thread.hasDiscussion {
                readOnlySummary
            }
        }
        .padding(.top, 4)
        .id("discuss-thread-\(topic.rawValue)")
        .onChange(of: shouldFocusComposer) { _, shouldFocus in
            guard shouldFocus, isActive else { return }
            isComposerFocused = true
        }
        .onAppear {
            if shouldFocusComposer, isActive {
                isComposerFocused = true
            }
        }
    }

    @ViewBuilder
    private func messageView(_ message: CoachDiscussMessage) -> some View {
        switch message.kind {
        case .typing:
            HStack(spacing: 8) {
                CoachTypingIndicator()
                Text("Coach is thinking about \(topic.title.lowercased())…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Coach is thinking about \(topic.title)")

        case .suggestions(let suggestions):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(suggestions, id: \.topic) { suggestion in
                    Button {
                        onApplySuggestion(suggestion)
                    } label: {
                        Label("Apply: \(suggestion.suggestedValue)", systemImage: "checkmark.circle")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Apply suggested \(topic.title) change")
                }
            }

        case .text(let text):
            discussBubble(text: text, role: message.role)
        }
    }

    private func discussBubble(text: String, role: CoachDiscussMessageRole) -> some View {
        HStack {
            if role == .user { Spacer(minLength: 24) }
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: bubbleCorners(for: role),
                        style: .continuous
                    )
                    .fill(bubbleFill(for: role))
                )
                .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
            if role != .user { Spacer(minLength: 24) }
        }
        .accessibilityLabel(accessibilityLabel(for: role, text: text))
    }

    private var activeComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Ask about \(topic.title.lowercased())…", text: $draftText, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .textFieldStyle(.roundedBorder)
                    .focused($isComposerFocused)
                    .accessibilityLabel("Ask about \(topic.title)")

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .disabled(thread.isThinking || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }

            Button("Done discussing", action: onDone)
                .font(.caption.weight(.semibold))
                .accessibilityHint("Stop discussing \(topic.title)")
        }
    }

    private var readOnlySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = thread.latestCoachSummary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button("Continue discussing", action: onReopenDiscuss)
            .font(.caption.weight(.semibold))
            .accessibilityHint("Reopen discussion for \(topic.title)")
        }
    }

    private func bubbleCorners(for role: CoachDiscussMessageRole) -> RectangleCornerRadii {
        switch role {
        case .user:
            return .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 4, topTrailing: 12)
        case .coach, .system:
            return .init(topLeading: 4, bottomLeading: 12, bottomTrailing: 12, topTrailing: 12)
        }
    }

    private func bubbleFill(for role: CoachDiscussMessageRole) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.16)
        case .coach:
            return FitlogPalette.subtleFill
        case .system:
            return FitlogPalette.highlight.opacity(0.12)
        }
    }

    private func accessibilityLabel(for role: CoachDiscussMessageRole, text: String) -> String {
        switch role {
        case .user: return "You said \(text)"
        case .coach: return "Coach said \(text)"
        case .system: return text
        }
    }
}

#Preview("Active thread") {
    CoachInlineDiscussThread(
        topic: .split,
        thread: CoachDiscussThread(
            topic: .split,
            messages: [
                CoachDiscussMessage(role: .coach, kind: .text("Ask me anything about split style — happy to explain the tradeoffs.")),
                CoachDiscussMessage(role: .user, kind: .text("Why not PPL?")),
                CoachDiscussMessage(role: .coach, kind: .text("PPL works best when you can train often enough to hit each pattern twice per week.")),
            ]
        ),
        draftText: .constant(""),
        isActive: true,
        shouldFocusComposer: false,
        onSend: {},
        onApplySuggestion: { _ in },
        onDone: {},
        onReopenDiscuss: {}
    )
    .padding()
}

#Preview("Thinking with suggestions") {
    CoachInlineDiscussThread(
        topic: .cardio,
        thread: CoachDiscussThread(
            topic: .cardio,
            messages: [
                CoachDiscussMessage(role: .user, kind: .text("Can we skip cardio?")),
                CoachDiscussMessage(role: .coach, kind: .typing),
            ],
            pendingSuggestions: [
                CoachFollowUpSuggestedChange(topic: "cardio", suggestedValue: "None — strength only"),
            ],
            isThinking: true
        ),
        draftText: .constant(""),
        isActive: true,
        shouldFocusComposer: false,
        onSend: {},
        onApplySuggestion: { _ in },
        onDone: {},
        onReopenDiscuss: {}
    )
    .padding()
}
