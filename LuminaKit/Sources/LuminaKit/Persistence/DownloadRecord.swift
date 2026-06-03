import Foundation
import SwiftData

/// One history entry. CloudKit-safe: every property has a default value, there are no
/// unique constraints, and the relationship is optional with a cascade delete rule.
/// Note: only this metadata syncs via CloudKit — the media file itself stays on-device.
@Model
public final class DownloadRecord {
    public var id: UUID = UUID()
    public var sourceURLString: String = ""
    public var service: String?
    public var filename: String = ""
    /// Path relative to the App Group `Downloads/` directory, if the file is local.
    public var relativePath: String?
    public var mediaKindRaw: Int = MediaKind.unknown.rawValue
    public var statusRaw: Int = DownloadStatus.pending.rawValue
    public var fileSize: Int64 = 0
    public var createdAt: Date = Date.now
    /// Small inline thumbnail (kept under ~1 MB; intentionally not `.externalStorage`
    /// so it remains CloudKit-sync friendly).
    public var thumbnailData: Data?
    /// JSON-encoded `CobaltRequest` so a synced/cloud-only record can be re-downloaded.
    public var requestData: Data?

    @Relationship(deleteRule: .cascade, inverse: \DownloadItemFile.record)
    public var files: [DownloadItemFile]?

    public init(
        id: UUID = UUID(),
        sourceURLString: String = "",
        service: String? = nil,
        filename: String = "",
        relativePath: String? = nil,
        mediaKind: MediaKind = .unknown,
        status: DownloadStatus = .pending,
        fileSize: Int64 = 0,
        createdAt: Date = .now,
        thumbnailData: Data? = nil,
        requestData: Data? = nil
    ) {
        self.id = id
        self.sourceURLString = sourceURLString
        self.service = service
        self.filename = filename
        self.relativePath = relativePath
        self.mediaKindRaw = mediaKind.rawValue
        self.statusRaw = status.rawValue
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
        self.requestData = requestData
        self.files = []
    }

    public var mediaKind: MediaKind {
        get { MediaKind(rawValue: mediaKindRaw) ?? .unknown }
        set { mediaKindRaw = newValue.rawValue }
    }

    public var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Whether the local file is missing (e.g. a record synced from another device).
    public var isCloudOnly: Bool { localFileURL == nil && (files?.isEmpty ?? true) }

    /// Absolute URL of the downloaded file, if it exists on this device.
    public var localFileURL: URL? {
        guard let relativePath, let downloads = AppGroup.downloadsDirectory() else { return nil }
        let url = downloads.appending(path: relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The decoded original request, for re-downloading a synced/cloud-only record.
    public var decodedRequest: CobaltRequest? {
        guard let requestData else { return nil }
        return try? JSONDecoder().decode(CobaltRequest.self, from: requestData)
    }
}
