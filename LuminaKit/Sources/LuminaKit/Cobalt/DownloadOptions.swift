import Foundation

/// UI-facing, fully-populated set of download options. `makeRequest(url:)` maps it
/// to a `CobaltRequest`, emitting only values that differ from the Cobalt default so
/// the request body stays minimal and forward-compatible.
public struct DownloadOptions: Codable, Sendable, Equatable {
    public var videoQuality: VideoQuality = .default
    public var audioFormat: AudioFormat = .default
    public var audioBitrate: AudioBitrate = .default
    public var downloadMode: DownloadMode = .default
    public var filenameStyle: FilenameStyle = .default
    public var disableMetadata: Bool = false
    public var alwaysProxy: Bool = false
    public var localProcessing: LocalProcessingMode = .default
    public var subtitleLang: String?

    public var youtubeVideoCodec: YouTubeVideoCodec = .default
    public var youtubeVideoContainer: YouTubeVideoContainer = .default
    public var youtubeDubLang: String?
    public var youtubeBetterAudio: Bool = false
    public var youtubeHLS: Bool = false

    public var convertGif: Bool = true
    public var allowH265: Bool = false
    public var tiktokFullAudio: Bool = false

    public init() {}

    /// Build a request, sending a field only when it deviates from the server default.
    public func makeRequest(url: String) -> CobaltRequest {
        var r = CobaltRequest(url: url)
        if videoQuality != .default { r.videoQuality = videoQuality }
        if audioFormat != .default { r.audioFormat = audioFormat }
        if audioBitrate != .default { r.audioBitrate = audioBitrate }
        if downloadMode != .default { r.downloadMode = downloadMode }
        if filenameStyle != .default { r.filenameStyle = filenameStyle }
        if disableMetadata { r.disableMetadata = true }
        if alwaysProxy { r.alwaysProxy = true }
        if localProcessing != .default { r.localProcessing = localProcessing }
        if let subtitleLang, !subtitleLang.isEmpty { r.subtitleLang = subtitleLang }

        if youtubeVideoCodec != .default { r.youtubeVideoCodec = youtubeVideoCodec }
        if youtubeVideoContainer != .default { r.youtubeVideoContainer = youtubeVideoContainer }
        if let youtubeDubLang, !youtubeDubLang.isEmpty { r.youtubeDubLang = youtubeDubLang }
        if youtubeBetterAudio { r.youtubeBetterAudio = true }
        if youtubeHLS { r.youtubeHLS = true }

        if !convertGif { r.convertGif = false } // server default is true
        if allowH265 { r.allowH265 = true }
        if tiktokFullAudio { r.tiktokFullAudio = true }
        return r
    }
}
