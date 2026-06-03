//
//  DownloadCoordinator.swift
//  Lumina
//
//  Actor that owns the single background URLSession, the task↔record mapping, and all
//  writes to its own ModelContext. It is the only place files are moved into the App
//  Group container and DownloadRecords are mutated off the main actor.
//

import Foundation
import SwiftData
import LuminaKit

actor DownloadCoordinator: DownloadEventSink {
    private let container: ModelContainer
    /// Created lazily inside the actor so the (non-Sendable) context belongs to this actor.
    private lazy var context = ModelContext(container)
    private var session: URLSession?
    private var delegate: BackgroundSessionDelegate?
    private var entries: [Int: Entry] = [:]
    private let continuation: AsyncStream<DownloadProgress>.Continuation
    nonisolated let events: AsyncStream<DownloadProgress>

    private struct Entry {
        let recordID: UUID
        let filename: String
        let mediaKind: MediaKind
        var bytesWritten: Int64 = 0
        var totalBytes: Int64 = -1
    }

    init(container: ModelContainer) {
        self.container = container
        var cont: AsyncStream<DownloadProgress>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(128)) { cont = $0 }
        self.continuation = cont
    }

    /// Recreate the background session after an app relaunch so queued completion events
    /// are delivered to the delegate.
    func reconnect() {
        _ = ensureSession()
    }

    /// Create a history record and start downloading `downloadURL` into the App Group.
    @discardableResult
    func start(sourceURL: String,
               downloadURL: URL,
               filename: String,
               service: String?,
               mediaKind: MediaKind,
               auth: CobaltConfiguration.Auth?,
               requestData: Data?) -> UUID {
        let id = UUID()
        let record = DownloadRecord(
            id: id,
            sourceURLString: sourceURL,
            service: service,
            filename: filename,
            mediaKind: mediaKind,
            status: .downloading,
            requestData: requestData)
        context.insert(record)
        try? context.save()

        let session = ensureSession()
        var request = URLRequest(url: downloadURL)
        if let auth { request.setValue(auth.headerValue, forHTTPHeaderField: "Authorization") }
        let task = session.downloadTask(with: request)
        entries[task.taskIdentifier] = Entry(recordID: id, filename: filename, mediaKind: mediaKind)
        task.resume()
        emit(id, filename, 0, -1, .downloading)
        return id
    }

    /// Run a Cobalt `local-processing` response: download the tunnels, combine them with the
    /// on-device engine, and import the result into the App Group as a completed record.
    func processLocally(payload: LocalProcessingPayload,
                        auth: CobaltConfiguration.Auth?,
                        sourceURL: String,
                        requestData: Data?) async {
        let id = UUID()
        let filename = payload.output.filename.isEmpty ? "output" : payload.output.filename
        let mediaKind = MediaKind.from(mime: payload.output.type, filename: filename)
        let record = DownloadRecord(
            id: id, sourceURLString: sourceURL, service: payload.service,
            filename: filename, mediaKind: mediaKind, status: .processing, requestData: requestData)
        context.insert(record)
        try? context.save()
        emit(id, filename, 0, -1, .processing)

        let workDir = FileManager.default.temporaryDirectory.appending(path: "lp-\(id.uuidString)", directoryHint: .isDirectory)
        do {
            let service = LocalProcessingService()
            let output = try await service.process(payload: payload, auth: auth, in: workDir)
            let finalURL = try placeFile(output, recordID: id, filename: filename)
            let size = (try? FileManager.default.attributesOfItem(atPath: finalURL.path))?[.size] as? Int64 ?? 0
            try? FileManager.default.removeItem(at: workDir)
            updateRecord(id) { rec in
                rec.relativePath = "\(id.uuidString)/\(filename)"
                rec.fileSize = size
                rec.mediaKind = mediaKind
                rec.status = .completed
            }
            emit(id, filename, size, size, .completed)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            updateRecord(id) { $0.status = .failed }
            emit(id, filename, 0, -1, .failed(error.localizedDescription))
        }
    }

    func cancel(recordID: UUID) async {
        guard let session else { return }
        let tasks = await session.allTasks
        for task in tasks where entries[task.taskIdentifier]?.recordID == recordID {
            task.cancel()
        }
        if let pair = entries.first(where: { $0.value.recordID == recordID }) {
            entries[pair.key] = nil
        }
        updateRecord(recordID) { $0.status = .canceled }
        emit(recordID, "", 0, -1, .canceled)
    }

    // MARK: - DownloadEventSink

    func handleWrote(taskID: Int, totalBytesWritten: Int64, totalBytesExpected: Int64, estimatedLength: Int64) {
        guard var entry = entries[taskID] else { return }
        entry.bytesWritten = totalBytesWritten
        entry.totalBytes = totalBytesExpected > 0 ? totalBytesExpected : estimatedLength
        entries[taskID] = entry
        emit(entry.recordID, entry.filename, entry.bytesWritten, entry.totalBytes, .downloading)
    }

    func handleFinished(taskID: Int, movedTempURL: URL, statusCode: Int) {
        guard let entry = entries[taskID] else {
            try? FileManager.default.removeItem(at: movedTempURL)
            return
        }
        defer { entries[taskID] = nil }

        guard (200..<300).contains(statusCode) else {
            try? FileManager.default.removeItem(at: movedTempURL)
            fail(entry, "HTTP \(statusCode)")
            return
        }
        do {
            let finalURL = try placeFile(movedTempURL, recordID: entry.recordID, filename: entry.filename)
            let size = (try? FileManager.default.attributesOfItem(atPath: finalURL.path))?[.size] as? Int64 ?? 0
            updateRecord(entry.recordID) { rec in
                rec.relativePath = "\(entry.recordID.uuidString)/\(entry.filename)"
                rec.fileSize = size
                rec.mediaKind = entry.mediaKind
                rec.status = .completed
            }
            emit(entry.recordID, entry.filename, size, size, .completed)
        } catch {
            fail(entry, error.localizedDescription)
        }
    }

    func handleCompleted(taskID: Int, errorMessage: String?, statusCode: Int) {
        // Success is finalized in handleFinished; here we only handle transport errors.
        guard let entry = entries[taskID], let errorMessage else { return }
        entries[taskID] = nil
        fail(entry, errorMessage)
    }

    // MARK: - Internals

    private func ensureSession() -> URLSession {
        if let session { return session }
        let holding = FileManager.default.temporaryDirectory
            .appending(path: "LuminaHolding", directoryHint: .isDirectory)
        let del = BackgroundSessionDelegate(sink: self, holdingDirectory: holding)
        let config = URLSessionConfiguration.background(withIdentifier: AppGroup.backgroundSessionID)
        config.sharedContainerIdentifier = AppGroup.identifier
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let s = URLSession(configuration: config, delegate: del, delegateQueue: nil)
        session = s
        delegate = del
        return s
    }

    private func placeFile(_ temp: URL, recordID: UUID, filename: String) throws -> URL {
        guard let downloads = AppGroup.downloadsDirectory() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let dir = downloads.appending(path: recordID.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appending(path: filename.isEmpty ? "download" : filename)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    private func updateRecord(_ id: UUID, _ mutate: (DownloadRecord) -> Void) {
        let descriptor = FetchDescriptor<DownloadRecord>(predicate: #Predicate { $0.id == id })
        if let rec = try? context.fetch(descriptor).first {
            mutate(rec)
            try? context.save()
        }
    }

    private func fail(_ entry: Entry, _ message: String) {
        updateRecord(entry.recordID) { $0.status = .failed }
        emit(entry.recordID, entry.filename, entry.bytesWritten, entry.totalBytes, .failed(message))
    }

    private func emit(_ id: UUID, _ filename: String, _ written: Int64, _ total: Int64, _ state: DownloadProgress.State) {
        continuation.yield(DownloadProgress(id: id, filename: filename, bytesWritten: written, totalBytes: total, state: state))
    }
}
