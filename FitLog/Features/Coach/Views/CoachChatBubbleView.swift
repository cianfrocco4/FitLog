//
//  CoachChatBubbleView.swift
//  FitLog
//
//  Message bubble for the free-form Coach tab chat.
//

import SwiftUI

struct CoachChatBubbleView: View {
    let message: CoachChatMessage
    let onCopy: () -> Void
    let onRegenerate: (() -> Void)?
    let onFeedback: (CoachMessageFeedback?) -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.isUser { Spacer(minLength: 48) }

                if !message.isUser {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FitlogPalette.chartPrimary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(FitlogPalette.subtleFill))
                        .accessibilityHidden(true)
                }

                Group {
                    if message.isUser {
                        Text(message.text)
                    } else {
                        CoachMarkdownText(text: message.text)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if message.isUser {
                        Color.accentColor.opacity(0.2)
                    } else {
                        FitlogPalette.subtleFill
                    }
                }
                .clipShape(bubbleShape)

                if !message.isUser { Spacer(minLength: 48) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(message.isUser ? "You" : "Coach"): \(message.text)")

            if !message.isUser {
                assistantFooter
            }

            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
                    .accessibilityIdentifier(FitLogA11yID.coachChatBubble.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }

            Text(message.created, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Sent at \(message.created.formatted(date: .omitted, time: .shortened))")
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            ShareLink(item: message.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if let onRegenerate {
                Button("Regenerate", systemImage: "arrow.clockwise", action: onRegenerate)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var assistantFooter: some View {
        HStack(spacing: 12) {
            Button {
                onFeedback(message.feedback == .up ? nil : .up)
            } label: {
                Image(systemName: message.feedback == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel("Helpful")

            Button {
                onFeedback(message.feedback == .down ? nil : .down)
            } label: {
                Image(systemName: message.feedback == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .accessibilityLabel("Not helpful")

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 36)
    }

    /// Coach apply cards show their own last-load; skip here to avoid a duplicate caption.
    private var resolvedLastLoadCaption: String? {
        guard !message.isUser, message.actions.isEmpty else { return nil }
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return HollyLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.isUser {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16),
                style: .continuous
            )
        } else {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 4, bottomLeading: 16, bottomTrailing: 16, topTrailing: 16),
                style: .continuous
            )
        }
    }
}

#Preview("Coach reply — light") {
    CoachChatBubbleView(
        message: CoachChatMessage(
            role: .assistant,
            text: "Bench press looked solid. Want to repeat yesterday's working set?"
        ),
        onCopy: {},
        onRegenerate: {},
        onFeedback: { _ in },
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("User message — dark") {
    CoachChatBubbleView(
        message: CoachChatMessage(role: .user, text: "What should I train today?"),
        onCopy: {},
        onRegenerate: nil,
        onFeedback: { _ in },
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
