//
//  DownloadManager.swift
//  Lumina
//
//  Main-actor @Observable facade the UI binds to. Bridges the DownloadCoordinator actor's
//  event stream into observable state.
//

import Foundation
import SwiftData
import Observation
import LuminaKit

@MainActor
@Observable
final class DownloadManager {
    private let coordinator: DownloadCoordinator
    /// Active (in-flight) downloads keyed by record id.
    private(set) var active: [UUID: DownloadProgress] = [:]
    /// The most recent terminal event, for one-shot UI (toasts/alerts).
    private(set) var lastCompleted: DownloadProgress?

    init(container: ModelContainer) {
        coordinator = DownloadCoordinator(container: container)
        let events = coordinator.events
        Task { [weak self] in
            for await update in events {
                self?.apply(update)
            }
        }
    }

    var activeList: [DownloadProgress] {
        active.values.sorted { $0.filename < $1.filename }
    }

    func reconnect() async {
        await coordinator.reconnect()
    }

    @discardableResult
    func start(sourceURL: String,
               downloadURL: URL,
               filename: String,
               service: String?,
               mediaKind: MediaKind,
               auth: CobaltConfiguration.Auth?,
               request: CobaltRequest?) async -> UUID {
        let requestData = request.flatMap { try? JSONEncoder().encode($0) }
        return await coordinator.start(
            sourceURL: sourceURL,
            downloadURL: downloadURL,
            filename: filename,
            service: service,
            mediaKind: mediaKind,
            auth: auth,
            requestData: requestData)
    }

    func processLocally(payload: LocalProcessingPayload,
                        auth: CobaltConfiguration.Auth?,
                        sourceURL: String,
                        request: CobaltRequest?) async {
        let requestData = request.flatMap { try? JSONEncoder().encode($0) }
        await coordinator.processLocally(payload: payload, auth: auth, sourceURL: sourceURL, requestData: requestData)
    }

    func cancel(recordID: UUID) {
        Task { await coordinator.cancel(recordID: recordID) }
    }

    private func apply(_ p: DownloadProgress) {
        Task { await LiveActivityController.sync(p) }
        if p.isFinished {
            active[p.id] = nil
            lastCompleted = p
        } else {
            active[p.id] = p
        }
    }
}
