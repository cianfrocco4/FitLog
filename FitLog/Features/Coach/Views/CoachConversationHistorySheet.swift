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

    @Environment(\.dismiss) private var dismiss
    @State private var renameTarget: CoachConversationSummary?
    @State private var renameDraft = ""

    var body: some View {
        NavigationStack {
            List {
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
}
