//
//  DownloadProgressRow.swift
//  Lumina
//

import SwiftUI
import LuminaKit

struct DownloadProgressRow: View {
    let progress: DownloadProgress
    var onCancel: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.filename.isEmpty ? String(localized: "Processing…") : progress.filename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                progressBar
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if case .downloading = progress.state, let onCancel {
                Button(role: .destructive, action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.filename.isEmpty ? String(localized: "Processing") : progress.filename)
        .accessibilityValue(statusText)
    }

    @ViewBuilder private var icon: some View {
        switch progress.state {
        case .processing:
            Image(systemName: "gearshape.2").foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default:
            Image(systemName: "arrow.down.circle").foregroundStyle(.tint)
        }
    }

    @ViewBuilder private var progressBar: some View {
        switch progress.state {
        case .downloading:
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
        case .processing:
            ProgressView().progressViewStyle(.linear)
        default:
            EmptyView()
        }
    }

    private var statusText: String {
        switch progress.state {
        case .downloading:
            if let fraction = progress.fraction {
                let pct = Int(fraction * 100)
                return "\(pct)% · \(byteString(progress.bytesWritten)) / \(byteString(progress.totalBytes))"
            }
            return byteString(progress.bytesWritten)
        case .processing: return String(localized: "Processing on device…")
        case .completed: return String(localized: "Saved to library")
        case .failed(let message): return message
        case .canceled: return String(localized: "Canceled")
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
