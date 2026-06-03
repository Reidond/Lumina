import Foundation
import SwiftData

/// Factory for the SwiftData stack. The persistent store lives in the **App Group**
/// container so the widget and share extension read the same database; CloudKit syncs
/// the metadata (not the media files).
public enum LuminaStore {
    public static let schema = Schema([
        DownloadRecord.self,
        DownloadItemFile.self,
    ])

    /// Production configuration: App Group container + private CloudKit database.
    public static func sharedConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .private(AppGroup.iCloudContainer)
        )
    }

    /// Local on-disk configuration used when the App Group isn't available (e.g. an
    /// unsigned/dev build). No group container and no CloudKit, so it never traps.
    public static func localConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }

    /// In-memory configuration for tests and previews (no entitlements required).
    public static func inMemoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    }

    /// Build the production container. SwiftData *traps* (doesn't throw) when the App Group
    /// entitlement is missing, so we probe `AppGroup.containerURL()` first and fall back to a
    /// local store, keeping the app launchable in unsigned/dev builds.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: [inMemoryConfiguration()])
        }
        if AppGroup.containerURL() != nil {
            if let shared = try? ModelContainer(for: schema, configurations: [sharedConfiguration()]) {
                return shared
            }
        }
        return try ModelContainer(for: schema, configurations: [localConfiguration()])
    }
}
