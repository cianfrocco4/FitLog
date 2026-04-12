//
//  ProgressPhotosView.swift
//  FitLog
//

import PhotosUI
import SwiftUI
import UIKit

struct ProgressPhotosView: View {
    @EnvironmentObject private var dataVM: DataManager

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCompare = false
    private let gridColumns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        ScrollView {
            if dataVM.progressPhotoRecords.isEmpty {
                ContentUnavailableView(
                    "No progress photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Add dated photos to compare how you look over time.")
                )
                .padding(.top, 48)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(dataVM.progressPhotoRecords) { rec in
                        photoCell(rec)
                            .contextMenu {
                                Button(role: .destructive) {
                                    dataVM.deleteProgressPhoto(id: rec.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Progress photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Add", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Compare") {
                    showCompare = true
                }
                .disabled(dataVM.progressPhotoRecords.count < 2)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let raw = try? await newItem.loadTransferable(type: Data.self) else {
                    await MainActor.run { pickerItem = nil }
                    return
                }
                let dataOut: Data
                if let ui = UIImage(data: raw), let jpg = ui.jpegData(compressionQuality: 0.88) {
                    dataOut = jpg
                } else {
                    dataOut = raw
                }
                await MainActor.run {
                    try? dataVM.addProgressPhoto(imageData: dataOut, capturedAt: Date())
                    pickerItem = nil
                }
            }
        }
        .sheet(isPresented: $showCompare) {
            ProgressPhotoCompareSheet()
                .environmentObject(dataVM)
        }
    }

    @ViewBuilder
    private func photoCell(_ rec: ProgressPhotoRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let data = dataVM.progressPhotoImageData(fileName: rec.fileName),
                   let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.2)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(HistoryView.formatDateStatic(rec.capturedAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct ProgressPhotoCompareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataVM: DataManager

    @State private var leftId: UUID?
    @State private var rightId: UUID?

    private var records: [ProgressPhotoRecord] { dataVM.progressPhotoRecords }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Before", selection: $leftId) {
                        Text("Choose…").tag(nil as UUID?)
                        ForEach(records) { r in
                            Text(HistoryView.formatDateStatic(r.capturedAt)).tag(Optional(r.id))
                        }
                    }
                    Picker("After", selection: $rightId) {
                        Text("Choose…").tag(nil as UUID?)
                        ForEach(records) { r in
                            Text(HistoryView.formatDateStatic(r.capturedAt)).tag(Optional(r.id))
                        }
                    }
                } footer: {
                    Text("Pick two different photos. Dates are shown under each image in the grid.")
                        .font(.caption2)
                }

                if let a = leftId, let b = rightId, a != b,
                   let la = records.first(where: { $0.id == a }),
                   let lb = records.first(where: { $0.id == b }),
                   let da = dataVM.progressPhotoImageData(fileName: la.fileName),
                   let db = dataVM.progressPhotoImageData(fileName: lb.fileName),
                   let ia = UIImage(data: da),
                   let ib = UIImage(data: db) {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 6) {
                                Text("Before")
                                    .font(.caption.weight(.semibold))
                                Image(uiImage: ia)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(HistoryView.formatDateStatic(la.capturedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 6) {
                                Text("After")
                                    .font(.caption.weight(.semibold))
                                Image(uiImage: ib)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(HistoryView.formatDateStatic(lb.capturedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if records.count >= 2 {
                leftId = records[1].id
                rightId = records[0].id
            }
        }
    }
}
