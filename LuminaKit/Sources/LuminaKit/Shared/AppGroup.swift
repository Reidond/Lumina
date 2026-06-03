import Foundation

/// Centralized identifiers shared by the app, Share Extension, and Widget. Keep these
/// in sync with the entitlements files and the Apple Developer portal.
public enum AppGroup {
    public static let identifier = "group.xyz.andriishafar.Lumina"
    /// Bare keychain group; callers prefix with `$(AppIdentifierPrefix)` via entitlements.
    public static let keychainGroup = "xyz.andriishafar.Lumina.shared"
    public static let iCloudContainer = "iCloud.xyz.andriishafar.Lumina"
    public static let backgroundSessionID = "xyz.andriishafar.Lumina.bg"
    public static let urlScheme = "lumina"

    public static let apiKeyKeychainService = "xyz.andriishafar.Lumina.cobalt-api-key"
    public static let bearerKeychainService = "xyz.andriishafar.Lumina.cobalt-bearer"

    /// Root of the shared App Group container.
    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Root for app data: the App Group container when available, otherwise the app's own
    /// Application Support directory (keeps unsigned/dev builds working).
    private static func storageRoot() -> URL? {
        containerURL() ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// `Downloads/` directory (created on demand).
    public static func downloadsDirectory() -> URL? {
        guard let root = storageRoot() else { return nil }
        let dir = root.appending(path: "Downloads", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Inbox where the Share Extension drops pending URLs for the app to pick up.
    public static func inboxDirectory() -> URL? {
        guard let root = storageRoot() else { return nil }
        let dir = root.appending(path: "Inbox", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
