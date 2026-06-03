import Foundation

/// Cobalt option enums. Raw values match the Cobalt v10 API exactly; `default`
/// mirrors the server-side default so we can omit unchanged values from requests.

public enum VideoQuality: String, Codable, CaseIterable, Sendable, Identifiable {
    case max
    case q4320 = "4320", q2160 = "2160", q1440 = "1440", q1080 = "1080"
    case q720 = "720", q480 = "480", q360 = "360", q240 = "240", q144 = "144"

    public static let `default`: VideoQuality = .q1080
    public var id: String { rawValue }
    public var displayName: String { self == .max ? "Max" : "\(rawValue)p" }
}

public enum AudioFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case best, mp3, ogg, wav, opus

    public static let `default`: AudioFormat = .mp3
    public var id: String { rawValue }
    public var displayName: String { self == .best ? "Best" : rawValue.uppercased() }
}

public enum AudioBitrate: String, Codable, CaseIterable, Sendable, Identifiable {
    case b320 = "320", b256 = "256", b128 = "128", b96 = "96", b64 = "64", b8 = "8"

    public static let `default`: AudioBitrate = .b128
    public var id: String { rawValue }
    public var displayName: String { "\(rawValue) kbps" }
}

public enum DownloadMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case auto, audio, mute

    public static let `default`: DownloadMode = .auto
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum FilenameStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic, pretty, basic, nerdy

    public static let `default`: FilenameStyle = .basic
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum YouTubeVideoCodec: String, Codable, CaseIterable, Sendable, Identifiable {
    case h264, av1, vp9

    public static let `default`: YouTubeVideoCodec = .h264
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .h264: "H.264"
        case .av1: "AV1"
        case .vp9: "VP9"
        }
    }
}

public enum YouTubeVideoContainer: String, Codable, CaseIterable, Sendable, Identifiable {
    case auto, mp4, webm, mkv

    public static let `default`: YouTubeVideoContainer = .auto
    public var id: String { rawValue }
    public var displayName: String { self == .auto ? "Auto" : rawValue.uppercased() }
}

public enum LocalProcessingMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case disabled, preferred, forced

    public static let `default`: LocalProcessingMode = .disabled
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}
