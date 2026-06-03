//
//  HistoryListView.swift
//  Lumina
//

import SwiftUI
import SwiftData
import LuminaKit

struct HistoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DownloadRecord.createdAt, order: .reverse) private var records: [DownloadRecord]
    @State private var search = ""

    private var filtered: [DownloadRecord] {
        guard !search.isEmpty else { return records }
        let q = search.lowercased()
        return records.filter {
            $0.filename.lowercased().contains(q)
            || ($0.service?.lowercased().contains(q) ?? false)
            || $0.sourceURLString.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(symbol: "clock",
                               title: String(localized: "No downloads yet"),
                               message: String(localized: "Fetched media will appear here."))
            } else {
                List {
                    ForEach(filtered) { record in
                        NavigationLink(value: record) {
                            HistoryRow(record: record)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .searchable(text: $search, prompt: Text("Search downloads"))
                .navigationDestination(for: DownloadRecord.self) { record in
                    HistoryDetailView(record: record)
                }
            }
        }
        .navigationTitle("History")
    }

    private func delete(_ record: DownloadRecord) {
        HistoryFiles.delete(record)
        context.delete(record)
        try? context.save()
    }
}

struct HistoryRow: View {
    let record: DownloadRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.mediaKind.sfSymbol)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.filename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
        .draggableFile(record.localFileURL)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let service = record.service { parts.append(service) }
        if record.fileSize > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: record.fileSize, countStyle: .file))
        }
        parts.append(record.createdAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var statusBadge: some View {
        switch record.status {
        case .completed:
            if record.isCloudOnly {
                Image(systemName: "icloud").foregroundStyle(.secondary)
            } else {
                EmptyView()
            }
        case .downloading, .processing: ProgressView()
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .canceled: Image(systemName: "slash.circle").foregroundStyle(.secondary)
        case .pending: Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }
}
