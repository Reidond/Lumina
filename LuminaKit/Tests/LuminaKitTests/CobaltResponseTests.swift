import Foundation
import Testing
@testable import LuminaKit

@Suite("CobaltResponse decoding")
struct CobaltResponseTests {
    let decoder = JSONDecoder()

    func decode(_ json: String) throws -> CobaltResponse {
        try decoder.decode(CobaltResponse.self, from: Data(json.utf8))
    }

    @Test func decodesTunnel() throws {
        let r = try decode(#"{"status":"tunnel","url":"https://x.test/tunnel?id=1&t=abc","filename":"video.mp4"}"#)
        guard case let .tunnel(url, filename) = r else { Issue.record("wrong case: \(r)"); return }
        #expect(url.absoluteString == "https://x.test/tunnel?id=1&t=abc")
        #expect(filename == "video.mp4")
    }

    @Test func decodesRedirect() throws {
        let r = try decode(#"{"status":"redirect","url":"https://cdn.test/a.mp4","filename":"a.mp4"}"#)
        guard case .redirect = r else { Issue.record("wrong case: \(r)"); return }
    }

    @Test func decodesPicker() throws {
        let json = #"""
        {"status":"picker","audio":"https://x.test/audio.mp3","audioFilename":"a.mp3",
         "picker":[{"type":"photo","url":"https://x.test/1.jpg","thumb":"https://x.test/1t.jpg"},
                   {"type":"video","url":"https://x.test/2.mp4"}]}
        """#
        let r = try decode(json)
        guard case let .picker(items, audio, audioFilename) = r else { Issue.record("wrong case"); return }
        #expect(items.count == 2)
        #expect(items[0].type == .photo)
        #expect(items[0].thumb?.absoluteString == "https://x.test/1t.jpg")
        #expect(items[1].type == .video)
        #expect(items[1].thumb == nil)
        #expect(audio?.absoluteString == "https://x.test/audio.mp3")
        #expect(audioFilename == "a.mp3")
    }

    @Test func decodesLocalProcessing() throws {
        let json = #"""
        {"status":"local-processing","type":"merge","service":"youtube",
         "tunnel":["https://x.test/v","https://x.test/a"],
         "output":{"type":"video/mp4","filename":"yt.mp4","metadata":{"title":"Song","artist":"Band"}},
         "audio":{"copy":false,"format":"mp3","bitrate":"128"},"isHLS":false}
        """#
        let r = try decode(json)
        guard case let .localProcessing(p) = r else { Issue.record("wrong case"); return }
        #expect(p.type == .merge)
        #expect(p.service == "youtube")
        #expect(p.tunnels.count == 2)
        #expect(p.output.filename == "yt.mp4")
        #expect(p.output.metadata?["title"] == "Song")
        #expect(p.audio?.format == "mp3")
        #expect(p.isHLS == false)
    }

    @Test func errorStatusThrowsPayload() throws {
        let json = #"{"status":"error","error":{"code":"api.auth.key.invalid","context":{"service":"youtube"}}}"#
        #expect(throws: CobaltResponseErrorThrown.self) {
            _ = try decode(json)
        }
        do {
            _ = try decode(json)
        } catch let thrown as CobaltResponseErrorThrown {
            #expect(thrown.payload.code == "api.auth.key.invalid")
            #expect(thrown.payload.service == "youtube")
        }
    }

    @Test func unknownStatusThrows() {
        #expect(throws: (any Error).self) {
            _ = try decode(#"{"status":"teapot"}"#)
        }
    }
}
