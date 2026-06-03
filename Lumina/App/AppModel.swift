//
//  AppModel.swift
//  Lumina
//
//  Main-actor router/view-model for the core flow: holds the URL text + options, runs the
//  fetch against the configured instance, and routes the response (tunnel/redirect → download,
//  picker → selection sheet, local-processing → on-device engine, error → alert).
//

import Foundation
import Observation
import LuminaKit

@MainActor
@Observable
final class AppModel {
    enum Section: String, Hashable, CaseIterable, Identifiable {
        case download, history, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .download: String(localized: "Download")
            case .history: String(localized: "History")
            case .settings: String(localized: "Settings")
            }
        }
        var symbol: String {
            switch self {
            case .download: "arrow.down.circle"
            case .history: "clock"
            case .settings: "gearshape"
            }
        }
    }

    var section: Section = .download
    var urlText = ""
    var options: DownloadOptions
    var isFetching = false
    var showingOptions = false
    var pickerContext: PickerContext?
    var turnstileContext: TurnstileContext?
    var alert: AlertContext?

    let settings: SettingsStore
    let downloads: DownloadManager

    init(settings: SettingsStore, downloads: DownloadManager) {
        self.settings = settings
        self.downloads = downloads
        self.options = settings.defaultOptions
    }

    /// Re-run a history record's original source link through the current options.
    func redownload(_ record: DownloadRecord) {
        ingest(urlString: record.sourceURLString)
    }

    /// Entry point for pasted links, the share extension, drag-drop, and `lumina://` URLs.
    func ingest(urlString: String, autoFetch: Bool = true) {
        urlText = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        section = .download
        if autoFetch { Task { await fetch() } }
    }

    func fetch() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil || trimmed.contains(".") else {
            alert = AlertContext(.invalidURL); return
        }
        guard let config = settings.makeConfiguration() else {
            alert = AlertContext(.notConfigured); return
        }
        isFetching = true
        defer { isFetching = false }

        let client = CobaltClient(provider: StaticConfigurationProvider(config))
        let request = options.makeRequest(url: trimmed)
        do {
            let response = try await client.submit(request)
            await route(response, sourceURL: trimmed, request: request, auth: config.auth)
        } catch let error as LuminaError {
            if case .turnstileRequired = error {
                await requestTurnstile(sourceURL: trimmed, config: config)
            } else {
                alert = AlertContext(error)
            }
        } catch {
            alert = AlertContext(.transport(error.localizedDescription))
        }
    }

    // MARK: - Turnstile (public instances)

    private func requestTurnstile(sourceURL: String, config: CobaltConfiguration) async {
        let client = CobaltClient(provider: StaticConfigurationProvider(config))
        guard let info = try? await client.fetchInstanceInfo(url: config.instanceURL),
              let sitekey = info.cobalt?.turnstileSitekey, !sitekey.isEmpty else {
            alert = AlertContext(.turnstileRequired(sitekey: nil))
            return
        }
        turnstileContext = TurnstileContext(sitekey: sitekey, instanceURL: config.instanceURL, pendingURL: sourceURL)
    }

    /// Called by the challenge view with the solved token; mints a Bearer and retries.
    func completeTurnstile(token: String) async {
        guard let context = turnstileContext else { return }
        turnstileContext = nil
        do {
            let minted = try await SessionTokenService().mintToken(
                instanceURL: context.instanceURL, turnstileResponse: token)
            settings.storeBearer(token: minted.value, expiry: minted.expiry)
            urlText = context.pendingURL
            await fetch()
        } catch let error as LuminaError {
            if case .auth = error {
                alert = AlertContext(.transport(String(localized: "This instance rejected the verification. Public instances like api.cobalt.tools block third-party apps — point Lumina at a self-hosted instance, or one that accepts an API key, in Settings.")))
            } else {
                alert = AlertContext(error)
            }
        } catch {
            alert = AlertContext(.transport(error.localizedDescription))
        }
    }

    func cancelTurnstile() {
        turnstileContext = nil
    }

    private func route(_ response: CobaltResponse,
                       sourceURL: String,
                       request: CobaltRequest,
                       auth: CobaltConfiguration.Auth?) async {
        switch response {
        case let .tunnel(url, filename), let .redirect(url, filename):
            await downloads.start(sourceURL: sourceURL, downloadURL: url, filename: filename,
                                  service: nil, mediaKind: .from(mime: nil, filename: filename),
                                  auth: auth, request: request)
            urlText = ""
        case let .picker(items, audio, audioFilename):
            pickerContext = PickerContext(items: items, audio: audio, audioFilename: audioFilename,
                                          sourceURL: sourceURL, auth: auth, request: request)
        case let .localProcessing(payload):
            await downloads.processLocally(payload: payload, auth: auth, sourceURL: sourceURL, request: request)
            urlText = ""
        }
    }

    func confirmPicker(_ selected: [PickerItem], audio: Bool, context: PickerContext) async {
        for item in selected {
            let filename = pickerFilename(for: item)
            await downloads.start(sourceURL: context.sourceURL, downloadURL: item.url, filename: filename,
                                  service: nil, mediaKind: mediaKind(for: item),
                                  auth: context.auth, request: context.request)
        }
        if audio, let audioURL = context.audio {
            let filename = context.audioFilename ?? "audio.mp3"
            await downloads.start(sourceURL: context.sourceURL, downloadURL: audioURL, filename: filename,
                                  service: nil, mediaKind: .audio, auth: context.auth, request: context.request)
        }
        pickerContext = nil
        urlText = ""
    }

    private func pickerFilename(for item: PickerItem) -> String {
        let last = item.url.lastPathComponent
        if !last.isEmpty, last.contains(".") { return last }
        switch item.type {
        case .photo: return "photo.jpg"
        case .video: return "video.mp4"
        case .gif: return "image.gif"
        }
    }

    private func mediaKind(for item: PickerItem) -> MediaKind {
        switch item.type {
        case .photo: .image
        case .video: .video
        case .gif: .gif
        }
    }
}

/// Identifiable wrappers for SwiftUI `.sheet(item:)` / `.alert`.
struct PickerContext: Identifiable {
    let id = UUID()
    let items: [PickerItem]
    let audio: URL?
    let audioFilename: String?
    let sourceURL: String
    let auth: CobaltConfiguration.Auth?
    let request: CobaltRequest
}

struct TurnstileContext: Identifiable {
    let id = UUID()
    let sitekey: String
    let instanceURL: URL
    let pendingURL: String
}

struct AlertContext: Identifiable {
    let id = UUID()
    let error: LuminaError
    init(_ error: LuminaError) { self.error = error }
}
