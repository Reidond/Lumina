//
//  SettingsStore.swift
//  Lumina
//
//  @Observable settings backed by UserDefaults (deliberately NOT @AppStorage, so SwiftUI
//  observes changes through @Observable). The API key lives in the Keychain, never in
//  UserDefaults. Settings UI is built in P6; this is the model it binds to.
//

import Foundation
import Observation
import LuminaKit

enum SaveDestination: Int, CaseIterable, Identifiable, Sendable {
    case photosForVisualFilesForAudio = 0
    case alwaysPhotos = 1
    case alwaysFiles = 2

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .photosForVisualFilesForAudio: String(localized: "Photos (video/image), Files (audio)")
        case .alwaysPhotos: String(localized: "Always Photos")
        case .alwaysFiles: String(localized: "Always Files")
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    var instanceURLString: String {
        didSet { defaults.set(instanceURLString, forKey: Keys.instanceURL) }
    }
    var defaultOptions: DownloadOptions {
        didSet { persistOptions() }
    }
    var saveDestination: SaveDestination {
        didSet { defaults.set(saveDestination.rawValue, forKey: Keys.saveDestination) }
    }
    var didCompleteOnboarding: Bool {
        didSet { defaults.set(didCompleteOnboarding, forKey: Keys.didCompleteOnboarding) }
    }

    private let defaults: UserDefaults
    private let credentials: CobaltCredentialStore
    private let bearerStore: BearerTokenStore

    // Empty by default: the official api.cobalt.tools blocks third-party apps, so the
    // onboarding guide prompts the user for their own instance instead.
    static let defaultInstanceURL = ""

    init(defaults: UserDefaults = .standard,
         credentials: CobaltCredentialStore = CobaltCredentialStore(),
         bearerStore: BearerTokenStore = BearerTokenStore()) {
        self.defaults = defaults
        self.credentials = credentials
        self.bearerStore = bearerStore
        self.instanceURLString = defaults.string(forKey: Keys.instanceURL) ?? Self.defaultInstanceURL
        self.saveDestination = SaveDestination(rawValue: defaults.integer(forKey: Keys.saveDestination)) ?? .photosForVisualFilesForAudio
        self.didCompleteOnboarding = defaults.bool(forKey: Keys.didCompleteOnboarding)
        if let data = defaults.data(forKey: Keys.defaultOptions),
           let decoded = try? JSONDecoder().decode(DownloadOptions.self, from: data) {
            self.defaultOptions = decoded
        } else {
            self.defaultOptions = DownloadOptions()
        }
    }

    /// A validated instance URL (http/https only).
    var instanceURL: URL? {
        guard let url = URL(string: instanceURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host() != nil else { return nil }
        return url
    }

    var isConfigured: Bool { instanceURL != nil }

    func apiKey() -> String? {
        guard let host = instanceURL?.instanceHostKey else { return nil }
        return credentials.apiKey(forHost: host)
    }

    @discardableResult
    func setAPIKey(_ key: String?) -> Bool {
        guard let host = instanceURL?.instanceHostKey else { return false }
        return credentials.setAPIKey(key, forHost: host)
    }

    /// Build a networking configuration snapshot, or nil if no instance is set. Prefers an
    /// API key, then a valid Turnstile-minted Bearer token.
    func makeConfiguration() -> CobaltConfiguration? {
        guard let url = instanceURL else { return nil }
        if let key = apiKey() {
            return CobaltConfiguration(instanceURL: url, auth: .apiKey(key))
        }
        if let bearer = bearerStore.validToken(forHost: url.instanceHostKey) {
            return CobaltConfiguration(instanceURL: url, auth: .bearer(bearer))
        }
        return CobaltConfiguration(instanceURL: url, auth: nil)
    }

    /// Persist a Bearer token obtained from a solved Turnstile challenge.
    func storeBearer(token: String, expiry: Date) {
        guard let host = instanceURL?.instanceHostKey else { return }
        bearerStore.store(token: token, exp: expiry, forHost: host)
    }

    /// Save destination resolved for a given media kind.
    func shouldSaveToPhotos(for kind: MediaKind) -> Bool {
        switch saveDestination {
        case .alwaysPhotos: return kind != .audio
        case .alwaysFiles: return false
        case .photosForVisualFilesForAudio: return kind == .video || kind == .image || kind == .gif
        }
    }

    private func persistOptions() {
        if let data = try? JSONEncoder().encode(defaultOptions) {
            defaults.set(data, forKey: Keys.defaultOptions)
        }
    }

    private enum Keys {
        static let instanceURL = "instanceURLString"
        static let defaultOptions = "defaultOptions"
        static let saveDestination = "saveDestination"
        static let didCompleteOnboarding = "didCompleteOnboarding"
    }
}
