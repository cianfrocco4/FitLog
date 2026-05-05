//
//  FitLogRecoverySheet.swift
//  FitLog
//
//  Shown when the ModelContainer fails to open (e.g. migration error).
//  Provides three recovery paths: restore from latest backup, choose a
//  backup file, or destructively reset (last resort).
//

import SwiftUI

struct FitLogRecoverySheet: View {
    let error: Error
    let onRestoreLatest: () -> Void
    let onChooseFile: () -> Void
    let onReset: () -> Void

    @State private var showResetConfirm = false
    @State private var isRestoring = false
    @State private var restoreError: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    errorDetailSection
                    actionsSection
                    if let msg = restoreError {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 24)
            }
            .navigationTitle("Data Recovery")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog(
            "This will erase all your data and start fresh. This cannot be undone.",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase and Continue", role: .destructive) { onReset() }
            Button("Cancel", role: .cancel) {}
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("FitLog could not open your data")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("A database upgrade failed. Your workout history is safe in a backup — restore it below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var errorDetailSection: some View {
        GroupBox {
            Text(error.localizedDescription)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Technical detail", systemImage: "info.circle")
                .font(.caption.bold())
        }
        .padding(.horizontal)
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Primary: restore from latest backup
            Button {
                isRestoring = true
                restoreError = nil
                onRestoreLatest()
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Restore from latest backup", systemImage: "arrow.counterclockwise.circle.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRestoring)
            .sensoryFeedback(.success, trigger: isRestoring)
            .accessibilityLabel("Restore from latest backup")
            .accessibilityHint("Loads your most recent automatic backup")

            // Secondary: choose a backup file
            Button {
                restoreError = nil
                onChooseFile()
            } label: {
                Label("Choose backup file…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Choose backup file")
            .accessibilityHint("Opens Files to select a backup JSON")

            Divider()
                .padding(.vertical, 4)

            // Destructive: reset
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset and continue (erase all data)", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
            .sensoryFeedback(.warning, trigger: showResetConfirm)
            .accessibilityLabel("Reset and continue")
            .accessibilityHint("Erases all workout data and opens FitLog fresh. Cannot be undone.")
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Recovery Sheet") {
    FitLogRecoverySheet(
        error: FitLogMigrationError.backupNotFound,
        onRestoreLatest: {},
        onChooseFile: {},
        onReset: {}
    )
}

#Preview("Recovery Sheet – Dark") {
    FitLogRecoverySheet(
        error: FitLogMigrationError.decodingFailed("Unexpected null at keyPath exercises[3].id"),
        onRestoreLatest: {},
        onChooseFile: {},
        onReset: {}
    )
    .preferredColorScheme(.dark)
}
