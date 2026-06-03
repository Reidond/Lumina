import Foundation

/// The JSON body for `POST /`. Every option is optional so that the synthesized
/// `Codable` omits `nil` values (Swift encodes optionals with `encodeIfPresent`),
/// keeping the request minimal and letting the instance apply its own defaults.
public struct CobaltRequest: Codable, Sendable, Equatable {
    public var url: String

    public var videoQuality: VideoQuality?
    public var audioFormat: AudioFormat?
    public var audioBitrate: AudioBitrate?
    public var downloadMode: DownloadMode?
    public var filenameStyle: FilenameStyle?
    public var disableMetadata: Bool?
    public var alwaysProxy: Bool?
    public var localProcessing: LocalProcessingMode?
    public var subtitleLang: String?

    public var youtubeVideoCodec: YouTubeVideoCodec?
    public var youtubeVideoContainer: YouTubeVideoContainer?
    public var youtubeDubLang: String?
    public var youtubeBetterAudio: Bool?
    public var youtubeHLS: Bool?

    public var convertGif: Bool?
    public var allowH265: Bool?
    public var tiktokFullAudio: Bool?

    public init(url: String) {
        self.url = url
    }
}
