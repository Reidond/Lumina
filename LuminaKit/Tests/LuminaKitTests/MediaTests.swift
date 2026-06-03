import Foundation
import Testing
@testable import LuminaKit

@Suite("Local processing engine selection")
struct MediaTests {
    func payload(_ json: String) throws -> LocalProcessingPayload {
        try JSONDecoder().decode(LocalProcessingPayload.self, from: Data(json.utf8))
    }

    @Test func jobMapsFromPayload() throws {
        let p = try payload(#"""
        {"status":"local-processing","type":"merge","service":"youtube",
         "tunnel":["https://x.test/v","https://x.test/a"],
         "output":{"type":"video/mp4","filename":"clip.mp4","metadata":{"title":"T"}}}
        """#)
        let out = URL(fileURLWithPath: "/tmp/out.mp4")
        let job = LocalProcessingJob(payload: p, downloadedInputs: [URL(fileURLWithPath: "/tmp/v"), URL(fileURLWithPath: "/tmp/a")], outputURL: out)
        #expect(job.kind == .merge)
        #expect(job.inputs.count == 2)
        #expect(job.outputMIME == "video/mp4")
        #expect(job.metadata?["title"] == "T")
        #expect(job.outputURL == out)
    }

    @Test func avFoundationHandlesMp4ButNotWebm() {
        let engine = AVFoundationProcessor()
        let mp4 = LocalProcessingJob(kind: .merge,
                                     inputs: [URL(fileURLWithPath: "/tmp/input-0"), URL(fileURLWithPath: "/tmp/input-1")],
                                     outputURL: URL(fileURLWithPath: "/tmp/o.mp4"),
                                     outputMIME: "video/mp4")
        #expect(engine.canHandle(mp4) == true)

        let webm = LocalProcessingJob(kind: .merge,
                                      inputs: [URL(fileURLWithPath: "/tmp/input-0")],
                                      outputURL: URL(fileURLWithPath: "/tmp/o.webm"),
                                      outputMIME: "video/webm")
        #expect(engine.canHandle(webm) == false)

        let gif = LocalProcessingJob(kind: .gif, inputs: [], outputURL: URL(fileURLWithPath: "/tmp/o.gif"), outputMIME: "image/gif")
        #expect(engine.canHandle(gif) == false)
    }

    @Test func gifJobIsUnsupportedByAllEngines() async {
        // Neither AVFoundation nor FFmpeg implements gif yet → process must throw cleanly.
        let processor = LocalProcessor()
        let gif = LocalProcessingJob(kind: .gif, inputs: [], outputURL: URL(fileURLWithPath: "/tmp/o.gif"), outputMIME: "image/gif")
        await #expect(throws: LuminaError.self) {
            _ = try await processor.process(gif)
        }
    }
}
