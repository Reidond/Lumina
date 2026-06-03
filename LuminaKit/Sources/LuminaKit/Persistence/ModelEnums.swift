import Foundation

/// Kind of media a record holds. Stored as `Int` raw values on the `@Model` so the
/// SwiftData/CloudKit schema stays primitive.
public enum MediaKind: Int, Codable, Sendable, CaseIterable {
    case video = 0
    case audio = 1
    case image = 2
    case gif = 3
    case unknown = 4

    public var sfSymbol: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        case .gif: "rectangle.stack.badge.play"
        case .unknown: "doc"
        }
    }

    /// Best-effort classification from a MIME type or file extension.
    public static func from(mime: String?, filename: String?) -> MediaKind {
        let m = (mime ?? "").lowercased()
        if m.hasPrefix("video") { return .video }
        if m.hasPrefix("audio") { return .audio }
        if m == "image/gif" { return .gif }
        if m.hasPrefix("image") { return .image }
        let ext = (filename as NSString?)?.pathExtension.lowercased() ?? ""
        switch ext {
        case "mp4", "mov", "webm", "mkv", "m4v": return .video
        case "mp3", "ogg", "wav", "opus", "m4a", "flac": return .audio
        case "gif": return .gif
        case "jpg", "jpeg", "png", "heic", "webp": return .image
        default: return .unknown
        }
    }
}

public enum DownloadStatus: Int, Codable, Sendable {
    case pending = 0
    case downloading = 1
    case processing = 2
    case completed = 3
    case failed = 4
    case canceled = 5
}
