//
//  BackgroundSessionDelegate.swift
//  Lumina
//
//  URLSession calls these delegate methods on its background delegate queue, so under
//  default-MainActor isolation every method MUST be `nonisolated`. The delegate extracts
//  only Sendable primitives from the (non-Sendable) URLResponse and forwards them to the
//  DownloadCoordinator actor.
//

import Foundation

/// The actor-side receiver of download events. Actors are Sendable, so `any DownloadEventSink`
/// can cross into the delegate's `Task` closures safely.
protocol DownloadEventSink: Sendable {
    func handleWrote(taskID: Int, totalBytesWritten: Int64, totalBytesExpected: Int64, estimatedLength: Int64) async
    func handleFinished(taskID: Int, movedTempURL: URL, statusCode: Int) async
    func handleCompleted(taskID: Int, errorMessage: String?, statusCode: Int) async
}

final class BackgroundSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let sink: any DownloadEventSink
    private let holdingDirectory: URL

    init(sink: any DownloadEventSink, holdingDirectory: URL) {
        self.sink = sink
        self.holdingDirectory = holdingDirectory
        super.init()
        try? FileManager.default.createDirectory(at: holdingDirectory, withIntermediateDirectories: true)
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let est = Self.estimatedLength(from: downloadTask.response)
        let id = downloadTask.taskIdentifier
        Task { [sink] in
            await sink.handleWrote(taskID: id,
                                   totalBytesWritten: totalBytesWritten,
                                   totalBytesExpected: totalBytesExpectedToWrite,
                                   estimatedLength: est)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        // The temp file at `location` is deleted as soon as this method returns, so move
        // it to a stable holding location synchronously before hopping to the actor.
        let dest = holdingDirectory.appending(path: "task-\(id)-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            Task { [sink] in await sink.handleCompleted(taskID: id, errorMessage: error.localizedDescription, statusCode: status) }
            return
        }
        Task { [sink] in await sink.handleFinished(taskID: id, movedTempURL: dest, statusCode: status) }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        let id = task.taskIdentifier
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        let message = error?.localizedDescription
        Task { [sink] in await sink.handleCompleted(taskID: id, errorMessage: message, statusCode: status) }
    }

    private nonisolated static func estimatedLength(from response: URLResponse?) -> Int64 {
        guard let http = response as? HTTPURLResponse else { return -1 }
        if let v = http.value(forHTTPHeaderField: "Estimated-Content-Length"), let n = Int64(v) { return n }
        return -1
    }
}
