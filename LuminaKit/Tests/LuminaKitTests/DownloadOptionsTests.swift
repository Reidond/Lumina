import Foundation
import Testing
@testable import LuminaKit

@Suite("DownloadOptions → CobaltRequest mapping")
struct DownloadOptionsTests {
    func encodedKeys(_ request: CobaltRequest) throws -> Set<String> {
        let data = try JSONEncoder().encode(request)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return Set(obj.keys)
    }

    @Test func defaultsOmitEverythingButURL() throws {
        let req = DownloadOptions().makeRequest(url: "https://y.test/watch")
        let keys = try encodedKeys(req)
        #expect(keys == ["url"])
    }

    @Test func onlyNonDefaultsAreSent() throws {
        var opts = DownloadOptions()
        opts.videoQuality = .q2160
        opts.downloadMode = .audio
        opts.convertGif = false        // server default is true → must be emitted as false
        opts.tiktokFullAudio = true
        let req = opts.makeRequest(url: "https://y.test/watch")
        let keys = try encodedKeys(req)
        #expect(keys == ["url", "videoQuality", "downloadMode", "convertGif", "tiktokFullAudio"])
        #expect(req.videoQuality == .q2160)
        #expect(req.convertGif == false)
    }

    @Test func rawValuesMatchContract() {
        #expect(VideoQuality.q1080.rawValue == "1080")
        #expect(VideoQuality.max.rawValue == "max")
        #expect(AudioFormat.opus.rawValue == "opus")
        #expect(DownloadMode.mute.rawValue == "mute")
        #expect(FilenameStyle.nerdy.rawValue == "nerdy")
        #expect(YouTubeVideoCodec.h264.rawValue == "h264")
        #expect(LocalProcessingMode.forced.rawValue == "forced")
        #expect(AudioBitrate.b320.rawValue == "320")
    }

    @Test func emptyOptionalStringsAreNotSent() throws {
        var opts = DownloadOptions()
        opts.subtitleLang = ""
        opts.youtubeDubLang = ""
        let keys = try encodedKeys(opts.makeRequest(url: "u"))
        #expect(keys == ["url"])
    }
}
