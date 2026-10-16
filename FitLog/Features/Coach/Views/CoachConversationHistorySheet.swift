//
//  CoachConversationHistorySheet.swift
//  FitLog
//
//  Past Coach conversations picker.
//

import SwiftUI

struct CoachConversationHistorySheet: View {
    let conversations: [CoachConversationSummary]
    let currentID: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onRename: (UUID, String) -> Void
    let onNewChat: () -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var renameTarget: CoachConversationSummary?
    @State private var renameDraft = ""

    var body: some View {
        NavigationStack {
            List {
                if let lastLoad = resolvedLastLoadCaption {
                    Section {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(FitLogA11yID.coachConversationHistory.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last working set or last cardio duration from a completed session")
                            .accessibilityAddTraits(.isStaticText)
                    }
                }

                if conversations.isEmpty {
                    ContentUnavailableView(
                        "No past chats",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a conversation with your coach.")
                    )
                } else {
                    ForEach(conversations) { conversation in
                        Button {
                            onSelect(conversation.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(conversation.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if conversation.id == currentID {
                                        Text("Current")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                                    }
                                }
                                if let preview = conversation.previewText, !preview.isEmpty {
                                    Text(preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(conversation.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityHint("Open this conversation")
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                renameTarget = conversation
                                renameDraft = conversation.title
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Rename", systemImage: "pencil") {
                                renameTarget = conversation
                                renameDraft = conversation.title
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDelete(conversations[index].id)
                        }
                    }
                }
            }
            .navigationTitle("Chat history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New chat") {
                        onNewChat()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename chat", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Title", text: $renameDraft)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Save") {
                    if let target = renameTarget {
                        onRename(target.id, renameDraft)
                    }
                    renameTarget = nil
                }
            } message: {
                Text("Give this conversation a short title.")
            }
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return SageLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("Light") {
    CoachConversationHistorySheet(
        conversations: [
            CoachConversationSummary(
                id: UUID(),
                title: "Push week",
                createdAt: Date().addingTimeInterval(-86_400),
                updatedAt: Date(),
                messageCount: 4,
                previewText: "Let's keep bench at 185."
            )
        ],
        currentID: nil,
        onSelect: { _ in },
        onDelete: { _ in },
        onRename: { _, _ in },
        onNewChat: {},
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
}

#Preview("Dark · empty") {
    CoachConversationHistorySheet(
        conversations: [],
        currentID: nil,
        onSelect: { _ in },
        onDelete: { _ in },
        onRename: { _, _ in },
        onNewChat: {},
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
    .preferredColorScheme(.dark)
}
