//
//  DownloadProgress.swift
//  Lumina
//
//  Sendable snapshot of a download's progress, emitted by DownloadCoordinator (actor)
//  and consumed by DownloadManager on the main actor.
//

import Foundation

struct DownloadProgress: Identifiable, Sendable, Equatable {
    enum State: Sendable, Equatable {
        case downloading
        case processing
        case completed
        case failed(String)
        case canceled
    }

    let id: UUID            // the owning DownloadRecord id
    var filename: String
    var bytesWritten: Int64
    var totalBytes: Int64   // -1 when unknown (no Content-Length / Estimated-Content-Length)
    var state: State

    /// Determinate fraction in 0...1, or nil when the total size is unknown.
    var fraction: Double? {
        guard totalBytes > 0 else { return nil }
        return min(1, max(0, Double(bytesWritten) / Double(totalBytes)))
    }

    var isFinished: Bool {
        switch state {
        case .completed, .failed, .canceled: true
        case .downloading, .processing: false
        }
    }
}
