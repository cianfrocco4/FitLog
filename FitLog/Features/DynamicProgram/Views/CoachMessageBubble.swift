//
//  CoachMessageBubble.swift
//  FitLog
//
//  Reusable chat bubble for Guided Coach conversations.
//

import SwiftUI

struct CoachMessageBubble: View {
    let message: CoachMessage
    var animateEntrance: Bool = true
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var appeared = false

    var body: some View {
        Group {
            switch message.kind {
            case .trainerText(let text):
                VStack(alignment: .leading, spacing: 6) {
                    trainerBubble(text)
                    if let lastLoad = resolvedLastLoadCaption {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 36)
                            .accessibilityIdentifier(FitLogA11yID.coachTrainerBubble.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last working set or last cardio duration from a completed session")
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
            case .userReply(let text):
                userBubble(text)
            case .phaseDivider(let label):
                phaseDivider(label)
            case .typingIndicator:
                typingBubble
            default:
                EmptyView()
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            guard animateEntrance else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var resolvedLastLoadCaption: String? {
        guard case .trainerText = message.kind else { return nil }
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return HollyLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    private func trainerBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitlogPalette.chartPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(FitlogPalette.subtleFill))
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4, bottomLeading: 16, bottomTrailing: 16, topTrailing: 16), style: .continuous)
                        .fill(FitlogPalette.subtleFill)
                )
            Spacer(minLength: 48)
        }
        .accessibilityLabel("Coach: \(text)")
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16), style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                )
        }
        .accessibilityLabel("You: \(text)")
    }

    private func phaseDivider(_ label: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
        }
        .padding(.vertical, 8)
        .accessibilityLabel(label)
    }

    private var typingBubble: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitlogPalette.chartPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(FitlogPalette.subtleFill))
                .accessibilityHidden(true)

            CoachTypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(FitlogPalette.subtleFill)
                )
            Spacer(minLength: 48)
        }
        .accessibilityLabel("Coach is thinking")
    }
}

struct CoachTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1 : 0.55)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

struct CoachQuickReplyPills: View {
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        onSelect(option)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("Select this as your answer")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct CoachScheduleInput: View {
    @Binding var sessions: Int
    @Binding var weekdays: Set<Int>
    let onSubmit: () -> Void

    private var maxSessions: Int {
        CoachScheduleSync.maxSessions(for: weekdays)
    }

    private var orderedWeekdays: [Int] {
        CoachScheduleSync.orderedWeekdayNumbers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(
                value: Binding(
                    get: { CoachScheduleSync.clampSessions(sessions, to: weekdays) },
                    set: { sessions = CoachScheduleSync.clampSessions($0, to: weekdays) }
                ),
                in: 1 ... maxSessions
            ) {
                Text("Sessions per week: \(CoachScheduleSync.clampSessions(sessions, to: weekdays))")
            }
            .accessibilityLabel("Sessions per week")
            .accessibilityValue("\(CoachScheduleSync.clampSessions(sessions, to: weekdays))")

            Text("Preferred days (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(orderedWeekdays, id: \.self) { day in
                    let selected = weekdays.contains(day)
                    let symbol = CoachScheduleSync.shortSymbol(for: day)
                    Button {
                        let result = CoachScheduleSync.toggleWeekday(day, sessions: sessions, weekdays: weekdays)
                        weekdays = result.weekdays
                        sessions = result.sessions
                    } label: {
                        Text(String(symbol.prefix(1)))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Color.accentColor.opacity(0.2) : FitlogPalette.subtleFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(symbol), \(selected ? "selected" : "not selected")")
                    .accessibilityHint(selected ? "Deselect training day" : "Select training day")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            Button("Continue", action: onSubmit)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Confirm your training schedule")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .onAppear {
            sessions = CoachScheduleSync.clampSessions(sessions, to: weekdays)
        }
        .onChange(of: weekdays) { _, newValue in
            sessions = CoachScheduleSync.clampSessions(sessions, to: newValue)
        }
    }
}

#Preview("Trainer bubble") {
    CoachMessageBubble(
        message: CoachMessage(kind: .trainerText("Let's build your program.")),
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
        .padding()
}

#Preview("Typing indicator") {
    CoachTypingIndicator()
        .padding()
}
