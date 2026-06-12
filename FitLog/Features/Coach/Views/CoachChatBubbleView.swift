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

            if !message.isUser {
                assistantFooter
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.isUser ? "You" : "Coach"): \(message.text)")
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
