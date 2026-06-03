import Foundation
import SwiftData

/// A single downloaded file belonging to a `DownloadRecord`. Used when a `picker`
/// response yields several media items grouped under one history entry.
@Model
public final class DownloadItemFile {
    public var id: UUID = UUID()
    public var filename: String = ""
    public var relativePath: String?
    public var mediaKindRaw: Int = MediaKind.unknown.rawValue
    public var fileSize: Int64 = 0
    public var sourceURLString: String?
    public var record: DownloadRecord?

    public init(
        id: UUID = UUID(),
        filename: String = "",
        relativePath: String? = nil,
        mediaKind: MediaKind = .unknown,
        fileSize: Int64 = 0,
        sourceURLString: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.mediaKindRaw = mediaKind.rawValue
        self.fileSize = fileSize
        self.sourceURLString = sourceURLString
    }

    public var mediaKind: MediaKind {
        get { MediaKind(rawValue: mediaKindRaw) ?? .unknown }
        set { mediaKindRaw = newValue.rawValue }
    }
}
