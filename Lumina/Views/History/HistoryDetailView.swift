//
//  HistoryDetailView.swift
//  Lumina
//

import SwiftUI
import SwiftData
import AVKit
import LuminaKit

struct HistoryDetailView: View {
    let record: DownloadRecord
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var saveMessage: String?
    @State private var showingSaveResult = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                metadata
                actions
            }
            .padding()
        }
        .navigationTitle(record.filename)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive, action: delete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if record.mediaKind == .video || record.mediaKind == .audio, let url = record.localFileURL {
                player = AVPlayer(url: url)
            }
        }
        .alert("Save", isPresented: $showingSaveResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveMessage ?? "")
        }
    }

    @ViewBuilder private var preview: some View {
        if let url = record.localFileURL {
            switch record.mediaKind {
            case .video, .audio:
                VideoPlayer(player: player)
                    .frame(height: record.mediaKind == .audio ? 80 : 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case .image, .gif:
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .draggableFile(url)
            case .unknown:
                fileIcon
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "icloud").font(.largeTitle)
                Text("Not on this device")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var fileIcon: some View {
        Image(systemName: record.mediaKind.sfSymbol)
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var metadata: some View {
        VStack(spacing: 8) {
            if let service = record.service {
                LabeledContent("Service", value: service)
            }
            LabeledContent("Source", value: record.sourceURLString)
            if record.fileSize > 0 {
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: record.fileSize, countStyle: .file))
            }
            LabeledContent("Added", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.subheadline)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let url = record.localFileURL {
                if record.mediaKind == .video || record.mediaKind == .image || record.mediaKind == .gif {
                    Button {
                        Task { await saveToPhotos(url: url) }
                    } label: {
                        Label("Save to Photos", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                ShareLink(item: url) {
                    Label("Share / Save to Files", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    app.redownload(record)
                    dismiss()
                } label: {
                    Label("Re-download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func saveToPhotos(url: URL) async {
        do {
            try await MediaSaver.saveToPhotos(fileURL: url, mediaKind: record.mediaKind)
            saveMessage = String(localized: "Saved to Photos.")
        } catch {
            saveMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        showingSaveResult = true
    }

    private func delete() {
        HistoryFiles.delete(record)
        context.delete(record)
        try? context.save()
        dismiss()
    }
}

/// On-disk cleanup for history records (SwiftData cascades the metadata; files are ours).
enum HistoryFiles {
    static func delete(_ record: DownloadRecord) {
        guard let downloads = AppGroup.downloadsDirectory() else { return }
        let dir = downloads.appending(path: record.id.uuidString, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: dir)
    }
}
